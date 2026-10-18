local scenario = require('tests.scenario')({ it = it })
local World = require('tests.scenario.world')

local function vgit(call)
  return 'lua require("vgit").' .. call
end

local function open_file(name, lnum)
  return {
    { cd = '$repo' },
    { edit = name },
    { cursor = { lnum or 1, 1 } },
  }
end

local function concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    vim.list_extend(out, list)
  end
  return out
end

describe('scenario: buffer actions', function()
  local base = World.numbered_lines(40, 'line')
  local edited = vim.deepcopy(base)
  edited[2] = 'CHANGED 2'
  edited[38] = 'CHANGED 38'

  scenario.flow('buffer_stage stages the whole file', {
    files = { ['f.txt'] = base },
    changes = { ['f.txt'] = edited },
    steps = concat(open_file('f.txt'), { { cmd = vgit('buffer_stage()') }, { settle = 500 } }),
    expect = { git_status = 'M  f.txt' },
  })

  scenario.flow('buffer_unstage unstages the whole file', {
    files = { ['f.txt'] = base },
    staged = { ['f.txt'] = edited },
    steps = concat(open_file('f.txt'), { { cmd = vgit('buffer_unstage()') }, { settle = 500 } }),
    expect = { git_status = ' M f.txt' },
  })

  scenario.flow('buffer_hunk_stage stages only the hunk under the cursor', {
    files = { ['f.txt'] = base },
    changes = { ['f.txt'] = edited },
    steps = concat(open_file('f.txt', 38), { { cmd = vgit('buffer_hunk_stage()') }, { settle = 800 } }),
    assert = function(ctx)
      local staged = ctx.world:git(ctx.repo, 'diff', '--cached', '--unified=0')
      assert.is_truthy(staged:find('CHANGED 38', 1, true))
      assert.is_falsy(staged:find('CHANGED 2', 1, true))
    end,
  })

  scenario.flow('buffer_hunk_reset reverts only the hunk under the cursor', {
    files = { ['f.txt'] = base },
    changes = { ['f.txt'] = edited },
    steps = concat(open_file('f.txt', 2), { { cmd = vgit('buffer_hunk_reset()') }, { settle = 800 } }),
    assert = function(ctx)
      local content = table.concat(vim.fn.readfile(ctx.repo .. '/f.txt'), '\n')
      assert.is_falsy(content:find('CHANGED 2', 1, true))
      assert.is_truthy(content:find('CHANGED 38', 1, true))
    end,
  })

  -- buffer_reset only rewrites the buffer (unsaved), whereas buffer_hunk_reset
  -- rewrites the file on disk. Pinned here so a change in either is deliberate.
  scenario.flow('buffer_reset restores the buffer to HEAD without saving it', {
    files = { ['f.txt'] = base },
    changes = { ['f.txt'] = edited },
    steps = concat(open_file('f.txt'), { { cmd = vgit('buffer_reset()') }, { settle = 800 } }),
    expect = { buffer_lines = base, git_status = ' M f.txt' },
  })

  scenario.flow('hunk_down moves the cursor to the next hunk', {
    files = { ['f.txt'] = base },
    changes = { ['f.txt'] = edited },
    steps = concat(open_file('f.txt', 1), {
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'gutter signs',
      },
      { cmd = vgit('hunk_down()') },
      { settle = 400 },
    }),
    expect = { cursor_line = 2 },
  })
end)

describe('scenario: conflicts', function()
  local conflict = { path = 'f.txt', ours = { 'ours' }, theirs = { 'theirs' } }

  scenario.flow('a merge conflict is listed in status without errors', {
    files = { ['f.txt'] = { 'base' } },
    conflict = conflict,
    steps = { { open = 'status' } },
    expect = { screen_has = { 'f.txt' } },
  })

  scenario.flow('accept current keeps our side of the conflict', {
    files = { ['f.txt'] = { 'base' } },
    conflict = conflict,
    steps = concat(open_file('f.txt', 2), {
      { settle = 600 },
      { cmd = vgit('buffer_conflict_accept_current()') },
      { settle = 400 },
    }),
    assert = function(ctx)
      local content = table.concat(ctx.observe.buffer_lines(ctx), '\n')
      assert.is_truthy(content:find('ours', 1, true), content)
      assert.is_falsy(content:find('theirs', 1, true), content)
      assert.is_falsy(content:find('<<<<<<<', 1, true), content)
    end,
  })

  scenario.flow('accept incoming keeps their side of the conflict', {
    files = { ['f.txt'] = { 'base' } },
    conflict = conflict,
    steps = concat(open_file('f.txt', 2), {
      { settle = 600 },
      { cmd = vgit('buffer_conflict_accept_incoming()') },
      { settle = 400 },
    }),
    assert = function(ctx)
      local content = table.concat(ctx.observe.buffer_lines(ctx), '\n')
      assert.is_truthy(content:find('theirs', 1, true), content)
      assert.is_falsy(content:find('ours', 1, true), content)
      assert.is_falsy(content:find('<<<<<<<', 1, true), content)
    end,
  })

  scenario.flow('accept both keeps both sides of the conflict', {
    files = { ['f.txt'] = { 'base' } },
    conflict = conflict,
    steps = concat(open_file('f.txt', 2), {
      { settle = 600 },
      { cmd = vgit('buffer_conflict_accept_both()') },
      { settle = 400 },
    }),
    assert = function(ctx)
      local content = table.concat(ctx.observe.buffer_lines(ctx), '\n')
      assert.is_truthy(content:find('ours', 1, true), content)
      assert.is_truthy(content:find('theirs', 1, true), content)
      assert.is_falsy(content:find('<<<<<<<', 1, true), content)
    end,
  })
end)

describe('scenario: commands', function()
  scenario.flow('show displays the diff of HEAD', {
    files = { ['f.txt'] = { 'one' } },
    history = { { message = 'edit f', files = { ['f.txt'] = { 'two' } } } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit show' },
      {
        await_text = 'two',
      },
    },
    expect = { screen_has = { 'f.txt', 'two' } },
  })

  scenario.flow('show accepts an explicit commit', {
    files = { ['f.txt'] = { 'one' } },
    history = {
      { message = 'edit f', files = { ['f.txt'] = { 'two' } } },
      { message = 'edit again', files = { ['f.txt'] = { 'three' } } },
    },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit show HEAD~1' },
      { await_text = 'two' },
    },
    expect = { screen_has = { 'f.txt', 'two' }, screen_hasnt = { 'three' } },
  })

  scenario.flow('hunk shows the hunk under the cursor', {
    files = { ['f.txt'] = World.numbered_lines(10, 'line') },
    changes = {
      ['f.txt'] = (function()
        local t = World.numbered_lines(10, 'line')
        t[5] = 'HUNK FIVE'
        return t
      end)(),
    },
    steps = concat(open_file('f.txt', 5), { { cmd = 'VGit hunk' }, { await_text = 'HUNK FIVE' } }),
    expect = { screen_has = { 'HUNK FIVE' } },
  })

  scenario.flow('hunk outside a file buffer reports an error', {
    files = { ['f.txt'] = { 'one' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit hunk' },
      {
        settle = 600,
      },
    },
    invariants = false,
    assert = function(ctx)
      assert.is_truthy(ctx.editor.terminal:is_alive())
    end,
  })

  scenario.flow('stash add stashes the changes', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit stash add' },
      {
        settle = 800,
      },
    },
    expect = { git_status = '' },
    assert = function(ctx)
      assert.is_truthy(ctx.world:git(ctx.repo, 'stash', 'list'):find('stash@{0}', 1, true))
    end,
  })

  scenario.flow('stash pop restores the changes', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    stashes = { 'wip' },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit stash pop' },
      {
        settle = 800,
      },
    },
    expect = { git_status = ' M f.txt' },
  })

  scenario.flow('stash drop removes the stash without applying it', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    stashes = { 'wip' },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit stash drop' },
      {
        settle = 800,
      },
    },
    expect = { git_status = '' },
    assert = function(ctx)
      assert.are.same('', ctx.world:git(ctx.repo, 'stash', 'list'))
    end,
  })

  scenario.flow('stash clear removes every stash', {
    files = { ['f.txt'] = { 'one' } },
    arrange = function(ctx)
      ctx.world:write(ctx.repo .. '/f.txt', { 'a' })
      ctx.world:stash(ctx.repo, 's1')
      ctx.world:write(ctx.repo .. '/f.txt', { 'b' })
      ctx.world:stash(ctx.repo, 's2')
    end,
    steps = {
      { cd = '$repo' },
      {
        cmd = 'VGit stash clear',
      },
      {
        settle = 800,
      },
    },
    assert = function(ctx)
      assert.are.same('', ctx.world:git(ctx.repo, 'stash', 'list'))
    end,
  })

  scenario.flow('commit with a message creates a commit', {
    files = { ['f.txt'] = { 'one' } },
    staged = { ['f.txt'] = { 'two' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit commit' },
      { settle = 800 },
      { keys = 'my message<C-s>' },
      { settle = 800 },
    },
    expect = { git_status = '', git_log = { 'my message', 'initial' } },
  })

  scenario.flow('an unknown command reports an error and stays usable', {
    files = { ['f.txt'] = { 'one' } },
    steps = { { cmd = 'VGit nonsense' }, { settle = 600 } },
    invariants = false,
    expect = { screen_has = { 'nonsense' } },
  })

  scenario.flow('debug status reports the state', {
    files = { ['f.txt'] = { 'one' } },
    steps = { { cmd = 'VGit debug status' }, { settle = 600 } },
    expect = { screen_has = { 'Debug mode' } },
  })

  scenario.flow('toggle_live_gutter removes and restores gutter signs', {
    files = { ['f.txt'] = { 'one', 'two' } },
    changes = { ['f.txt'] = { 'one', 'TWO' } },
    steps = concat(open_file('f.txt'), {
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'gutter signs',
      },
      { cmd = vgit('toggle_live_gutter()') },
      { settle = 600 },
    }),
    assert = function(ctx)
      assert.are.same(0, #ctx.observe.signs(ctx))
    end,
  })
end)
