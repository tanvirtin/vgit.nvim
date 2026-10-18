local World = require('tests.scenario.world')
local Editor = require('tests.scenario.editor')
local observe = require('tests.scenario.observe')
local dsl = require('tests.scenario.dsl')

local PLUGIN_ROOT = vim.fn.getcwd()

local TEST_TIMEOUT_MS = 30000

local function failure_report(err, editor, ctx)
  local message = type(err) == 'string' and err or vim.inspect(err)

  local function capture(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return '(unavailable: ' .. tostring(value) .. ')'
  end

  local parts = { message }

  parts[#parts + 1] = '--- alive: '
    .. capture(function()
      if editor.terminal:is_alive() then return 'yes' end
      return 'no (exit code ' .. tostring(editor.terminal._exit_code) .. ')'
    end)

  parts[#parts + 1] = '--- steps sent (oldest first):'
  parts[#parts + 1] = capture(function()
    return table.concat(editor:trace(), '\n')
  end)

  parts[#parts + 1] = '--- cwd: ' .. capture(function()
    return tostring(observe.cwd(ctx))
  end)
  parts[#parts + 1] = '--- repository: ' .. capture(function()
    return tostring(observe.repository_path(ctx))
  end)

  if ctx.repo then
    parts[#parts + 1] = '--- git status --porcelain:'
    parts[#parts + 1] = capture(function()
      return ctx.world:git_try(ctx.repo, 'status', '--porcelain')
    end)
  end

  parts[#parts + 1] = '--- screen (exactly as rendered):'
  parts[#parts + 1] = capture(function()
    return editor.terminal:screen()
  end)

  parts[#parts + 1] = '--- messages:'
  parts[#parts + 1] = capture(function()
    return editor.terminal:messages()
  end)

  return table.concat(parts, '\n')
end

return function(busted)
  local scenario = {}

  local function run(fn, opts)
    opts = opts or {}
    local world = World.new()
    local editor = Editor.start({
      root = world.root,
      cwd = world.root,
      env = world.env,
      plugin_root = PLUGIN_ROOT,
      config = opts.config,
    })
    local ctx = { world = world, editor = editor, observe = observe }

    -- Watchdog: a wedged child would otherwise hang the whole suite. Tearing the
    -- child down unblocks any wait() the test body is parked in (vim.wait pumps
    -- the loop, so this timer fires), and the test is reported as timed out.
    local timeout_ms = opts.timeout or TEST_TIMEOUT_MS
    local timed_out = false
    local timer = vim.uv.new_timer()
    timer:start(timeout_ms, 0, function()
      timed_out = true
      vim.schedule(function()
        pcall(editor.teardown, editor)
      end)
    end)

    local ok, err = xpcall(function()
      fn(ctx)
    end, debug.traceback)

    timer:stop()
    if not timer:is_closing() then timer:close() end

    if timed_out then
      ok = false
      err = string.format('scenario timed out after %dms', timeout_ms)
    end

    local report = not ok and failure_report(err, editor, ctx) or nil

    editor:teardown()
    world:teardown()

    return ok, report
  end

  -- Accepts either (name, fn) or (name, { config/timeout }, fn).
  local function split(second, third)
    if type(second) == 'function' then return nil, second end
    return second, third
  end

  function scenario.test(name, second, third)
    local opts, fn = split(second, third)
    busted.it(name, function()
      local ok, report = run(fn, opts)
      if not ok then error(report, 0) end
    end)
  end

  -- Declarative flow: a table with `arrange`/`repo`+`files`+`staged`+`changes`,
  -- a `steps` list, and `expect`. See tests/scenario/dsl.lua for the shape.
  function scenario.flow(name, spec)
    busted.it(name, function()
      local ok, report = run(function(ctx)
        dsl.execute(ctx, spec)
      end, { config = spec.config, timeout = spec.timeout })
      if not ok then error(report, 0) end
    end)
  end

  -- Passes while the bug reproduces; fails once it is fixed so the test gets promoted.
  function scenario.known_bug(name, reason, second, third)
    local opts, fn = split(second, third)
    busted.it(name .. ' [known bug: ' .. reason .. ']', function()
      local ok = run(fn, opts)
      if ok then error('known bug no longer reproduces; promote this to scenario.test', 0) end
    end)
  end

  return scenario
end
