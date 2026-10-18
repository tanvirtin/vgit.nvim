-- Declarative scenario layer.
--
-- A flow is a table with three parts, each optional:
--
--   * arrange  - a declarative world (one repo, files, staged/unstaged edits)
--                or a function(ctx) escape hatch for anything more exotic.
--   * steps    - an ordered list of steps the user performs.
--   * expect   - declarative assertions about git state and the rendered screen,
--                plus an `assert = function(ctx)` escape hatch.
--
-- Example:
--
--   scenario.flow('stage a file with s', {
--     files = { ['file.txt'] = { 'base' } },
--     changes = { ['file.txt'] = { 'changed' } },
--     steps = {
--       { open = 'status' },
--       { keys = 's' },
--     },
--     expect = {
--       git_status = 'M  file.txt',
--       screen_has = { 'file.txt' },
--       screen_hasnt = { 'E218' },
--     },
--   })
--
-- The point is that a whole "paint a screen, map it into an assertion" case
-- fits in one readable table, so the loop stays fast to iterate on.

local observe = require('tests.scenario.observe')

-- busted only injects its `assert` table into the spec chunk's environment, not
-- into required modules, so pull luassert in explicitly here.
local assert = require('luassert')

local dsl = {}

local CHECKPOINT_MS = 3000

local expect

-- Expands $repo / $name references against the context, so a step can point at a
-- repo path or a fixture (ctx.feature, ...) the arrange step stored.
local function resolve(value, ctx)
  if type(value) ~= 'string' then return value end
  return (
    value:gsub('%$(%w+)', function(name)
      if name == 'repo' then return ctx.repo end
      return ctx[name] or ('$' .. name)
    end)
  )
end

local function arrange(ctx, spec)
  if spec.files then ctx.repo = ctx.world:repo('main', spec.files) end

  -- staged edits are written and added; changes stay in the working tree.
  for path, lines in pairs(spec.staged or {}) do
    ctx.world:write(ctx.repo .. '/' .. path, lines)
    ctx.world:git(ctx.repo, 'add', path)
  end
  for path, lines in pairs(spec.changes or {}) do
    ctx.world:write(ctx.repo .. '/' .. path, lines)
  end

  for path, lines in pairs(spec.untracked or {}) do
    ctx.world:write(ctx.repo .. '/' .. path, lines)
  end
  for _, path in ipairs(spec.deleted or {}) do
    vim.fn.delete(ctx.repo .. '/' .. path)
  end
  if spec.history then ctx.world:history(ctx.repo, spec.history) end
  for _, branch_name in ipairs(spec.branches or {}) do
    ctx.world:branch(ctx.repo, branch_name)
  end
  if spec.conflict then
    local c = spec.conflict
    ctx.world:conflict(ctx.repo, c.path, c.ours, c.theirs)
  end
  for _, message in ipairs(spec.stashes or {}) do
    ctx.world:stash(ctx.repo, message)
  end

  -- Escape hatch for anything the shorthand cannot express; runs last so the
  -- repo, staged and working-tree state are already in place.
  if spec.arrange then spec.arrange(ctx) end
end

local function open(ctx, st)
  ctx.editor:cmd('cd ' .. ctx.repo)
  ctx.editor:cmd('VGit ' .. (st.open == true and 'status' or st.open))

  local await = st.await_text
  if st.open == 'status' and await == nil then await = 'Changes' end
  if await then ctx.editor:await_text(await) end

  ctx.editor:settle(st.settle_ms)
end

local function checkpoint(ctx, st)
  local deadline = vim.uv.now() + (st.settle_ms or CHECKPOINT_MS)
  local ok, err
  repeat
    ok, err = pcall(expect, ctx, { expect = st.expect })
    if ok then return end
    vim.wait(50)
  until vim.uv.now() >= deadline
  error(err, 0)
end

local function step(ctx, st)
  if st.run then
    st.run(ctx)
  elseif st.expect then
    checkpoint(ctx, st)
  elseif st.cd then
    ctx.editor:cmd('cd ' .. resolve(st.cd, ctx))
    ctx.editor:settle(st.settle_ms)
  elseif st.cmd then
    local text = type(st.cmd) == 'function' and st.cmd(ctx) or resolve(st.cmd, ctx)
    ctx.editor:cmd(text)
    ctx.editor:settle(st.settle_ms)
  elseif st.open then
    open(ctx, st)
  elseif st.keys then
    ctx.editor:keys(st.keys)
    ctx.editor:settle(st.settle_ms)
  elseif st.write then
    local target = resolve(st.write.path, ctx)
    if target:sub(1, 1) ~= '/' then target = ctx.repo .. '/' .. target end
    ctx.world:write(target, st.write.lines)
    ctx.editor:settle(st.settle_ms)
  elseif st.git then
    ctx.world:git(ctx.repo, unpack(st.git))
    ctx.editor:settle(st.settle_ms)
  elseif st.edit then
    ctx.editor:cmd('edit ' .. resolve(st.edit, ctx))
    ctx.editor:settle(st.settle_ms)
  elseif st.focus then
    -- Moves focus to the first window showing a buffer of this filetype. Floating
    -- borders sit between panes, so wincmd hops are not a reliable way to get there.
    -- Goes over RPC rather than a typed ":" command because the focused pane may
    -- be an insert-mode input that would swallow the keystrokes as text.
    local target = type(st.focus) == 'table' and st.focus or { filetype = st.focus }
    local found = ctx.editor.terminal:rpc_eval(string.format(
      [[(function()
        local target = vim.json.decode(%q)
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local b = vim.api.nvim_win_get_buf(w)
          local ok = true
          if target.filetype and vim.bo[b].filetype ~= target.filetype then ok = false end
          if ok and target.mapped then
            local m = vim.api.nvim_buf_call(b, function() return vim.fn.maparg(target.mapped, 'n') end)
            ok = m ~= ''
          end
          if ok then
            vim.api.nvim_set_current_win(w)
            vim.cmd('stopinsert')
            return true
          end
        end
        return false
      end)()]],
      vim.json.encode(target)
    ))
    assert(found == 'true', 'no window matched focus target ' .. vim.inspect(target))
    ctx.editor:settle(st.settle_ms)
  elseif st.search then
    ctx.editor:keys('/' .. st.search .. '<CR>')
    ctx.editor:settle(st.settle_ms)
  elseif st.cursor then
    ctx.editor:cmd(string.format('call cursor(%d, %d)', st.cursor[1], st.cursor[2] or 1))
    ctx.editor:settle(st.settle_ms)
  elseif st.await_text then
    ctx.editor:await_text(st.await_text, st.settle_ms)
  elseif st.await_no_text then
    ctx.editor:await_no_text(st.await_no_text, st.settle_ms)
  elseif st.await_filetype then
    ctx.editor:await_filetype(st.await_filetype, st.settle_ms)
  elseif st.wait_until then
    ctx.editor:wait_for(function()
      return st.wait_until(ctx)
    end, st.desc or 'the condition to hold', st.settle_ms)
  elseif st.snap then
    ctx._snaps[st.snap] = observe.frame(ctx)
  elseif st.dismiss then
    ctx.editor:wait_for_prompt(st.settle_ms)
    ctx.editor:dismiss()
  elseif st.settle then
    ctx.editor:settle(type(st.settle) == 'number' and st.settle or nil)
  else
    error('unrecognised step: ' .. vim.inspect(st), 2)
  end
end

function expect(ctx, spec)
  if spec.assert then spec.assert(ctx) end

  local e = spec.expect
  if not e then return end

  if e.git_status ~= nil then assert.are.same(e.git_status, ctx.world:git(ctx.repo, 'status', '--porcelain')) end

  for _, text in ipairs(e.screen_has or {}) do
    assert.is_truthy(observe.contains(ctx, text), string.format('expected screen to contain %q', text))
  end

  if e.messages_has then
    local messages = ctx.editor.terminal:messages()
    for _, text in ipairs(e.messages_has) do
      assert.is_truthy(
        messages:find(text, 1, true),
        string.format('expected :messages to contain %q, got %q', text, messages)
      )
    end
  end

  for _, text in ipairs(e.screen_hasnt or {}) do
    assert.is_falsy(observe.contains(ctx, text), string.format('expected screen NOT to contain %q', text))
  end

  if e.git_log then assert.are.same(e.git_log, vim.split(ctx.world:git(ctx.repo, 'log', '--format=%s'), '\n')) end

  for path, lines in pairs(e.file or {}) do
    assert.are.same(lines, vim.fn.readfile(ctx.repo .. '/' .. path))
  end

  if e.cursor_line ~= nil then assert.are.same(e.cursor_line, observe.cursor(ctx)[1]) end

  if e.buffer_lines then assert.are.same(e.buffer_lines, observe.buffer_lines(ctx)) end

  for _, group in ipairs(e.signs or {}) do
    local signs = observe.signs(ctx)
    local found = false
    for _, sign in ipairs(signs) do
      if sign.lnum == group.lnum and (group.hl == nil or sign.hl == group.hl) then found = true end
    end
    assert.is_truthy(
      found,
      string.format('expected a sign on line %d (%s); got %s', group.lnum, tostring(group.hl), vim.inspect(signs))
    )
  end

  if e.screen_changed then
    local from = ctx._snaps[e.screen_changed[1]]
    local to = ctx._snaps[e.screen_changed[2]]
    assert.is_truthy(from and to, 'screen_changed needs two named snapshots')
    assert.is_truthy(
      from ~= to,
      string.format('expected the screen to change between %q and %q', e.screen_changed[1], e.screen_changed[2])
    )
  end

  if e.screen_same then
    local from = ctx._snaps[e.screen_same[1]]
    local to = ctx._snaps[e.screen_same[2]]
    assert.is_truthy(from and to, 'screen_same needs two named snapshots')
    assert.are.same(from, to)
  end
end

-- Checks that hold after every flow unless it opts out with `invariants = false`:
-- the child is alive and neither the screen nor :messages carries a Vim error
-- (E123) or a Lua traceback. These catch regressions like E218 without each flow
-- having to assert their absence.
function dsl.check_invariants(ctx)
  assert.is_truthy(ctx.editor.terminal:is_alive(), 'the child Neovim exited during the flow')

  -- E1568 is the pty child complaining that the test terminal does not answer a
  -- background-color query; it is startup noise, not a plugin error.
  local haystack = observe.screen(ctx) .. '\n' .. ctx.editor.terminal:messages()
  haystack = haystack:gsub('E1568:[^\n]*', '')
  local code = haystack:match('E%d%d+:')
  assert.is_nil(code, 'a Vim error showed up: ' .. tostring(code))
  assert.is_falsy(haystack:find('stack traceback', 1, true), 'a Lua traceback showed up')
  assert.is_falsy(haystack:find('Error executing', 1, true), 'Neovim reported an execution error')
end

-- Executes a declarative flow inside a scenario context. Each phase and step is
-- annotated so a failure points at exactly where the flow went wrong.
function dsl.execute(ctx, spec)
  ctx._snaps = {}

  local ok, err = pcall(arrange, ctx, spec)
  if not ok then error('arrange failed: ' .. tostring(err), 0) end

  for index, st in ipairs(spec.steps or {}) do
    local step_ok, step_err = pcall(step, ctx, st)
    if not step_ok then
      error(string.format('step %d (%s) failed: %s', index, vim.inspect(st), tostring(step_err)), 0)
    end
  end

  local expect_ok, expect_err = pcall(expect, ctx, spec)
  if not expect_ok then error('expect failed: ' .. tostring(expect_err), 0) end

  if spec.invariants ~= false then
    local inv_ok, inv_err = pcall(dsl.check_invariants, ctx)
    if not inv_ok then error('invariant failed: ' .. tostring(inv_err), 0) end
  end
end

return dsl
