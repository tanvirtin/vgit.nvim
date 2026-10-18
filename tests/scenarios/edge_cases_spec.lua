local scenario = require('tests.scenario')({ it = it })
local World = require('tests.scenario.world')

describe('scenario: status edge cases', function()
  scenario.flow('a deleted file is listed and can be staged', {
    files = { ['gone.txt'] = { 'x' }, ['keep.txt'] = { 'y' } },
    deleted = { 'gone.txt' },
    steps = { { open = 'status' }, { keys = 's' } },
    expect = { screen_has = { 'gone.txt' }, git_status = 'D  gone.txt' },
  })

  scenario.flow('an untracked file is listed and can be staged', {
    files = { ['a.txt'] = { 'a' } },
    untracked = { ['new.txt'] = { 'n' } },
    steps = { { open = 'status' }, { keys = 's' } },
    expect = { screen_has = { 'new.txt' }, git_status = 'A  new.txt' },
  })

  scenario.flow('a renamed file shows in status without errors', {
    files = { ['old.txt'] = { 'same content', 'more' } },
    arrange = function(ctx)
      ctx.world:git(ctx.repo, 'mv', 'old.txt', 'new.txt')
    end,
    steps = { { open = 'status' } },
    expect = { screen_has = { 'new.txt' } },
  })

  scenario.flow('a binary file change does not break the status view', {
    files = { ['a.txt'] = { 'a' } },
    arrange = function(ctx)
      local f = io.open(ctx.repo .. '/bin.dat', 'wb')
      f:write('\0\1\2\3\0')
      f:close()
      ctx.world:git(ctx.repo, 'add', 'bin.dat')
      ctx.world:commit(ctx.repo, 'add binary')
      f = io.open(ctx.repo .. '/bin.dat', 'wb')
      f:write('\0\9\9\9\0')
      f:close()
    end,
    steps = { { open = 'status' } },
    expect = { screen_has = { 'bin.dat' } },
  })

  scenario.flow('status on a clean repo shows no changes and no errors', {
    files = { ['a.txt'] = { 'a' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit status' },
      {
        settle = 800,
      },
    },
    expect = { screen_hasnt = { 'Traceback' } },
  })

  scenario.flow('status works on a detached HEAD', {
    files = { ['a.txt'] = { 'a' } },
    changes = { ['a.txt'] = { 'b' } },
    arrange = function(ctx)
      ctx.world:git(ctx.repo, 'checkout', '-q', '--detach')
      ctx.world:write(ctx.repo .. '/a.txt', { 'b' })
    end,
    steps = { { open = 'status' }, { keys = 's' } },
    expect = { git_status = 'M  a.txt' },
  })

  scenario.flow('status outside a git repository reports an error and stays usable', {
    arrange = function(ctx)
      ctx.repo = ctx.world.root
    end,
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit status' },
      {
        settle = 800,
      },
    },
    invariants = false,
    assert = function(ctx)
      assert.is_truthy(ctx.editor.terminal:is_alive())
    end,
  })
end)

describe('scenario: hunk operations', function()
  local base = World.numbered_lines(40, 'line')
  local edited = vim.deepcopy(base)
  edited[2] = 'CHANGED 2'
  edited[38] = 'CHANGED 38'

  scenario.flow('staging one hunk leaves the other unstaged', {
    files = { ['f.txt'] = base },
    changes = { ['f.txt'] = edited },
    steps = {
      { open = 'status' },
      { focus = { mapped = '<leader>s' } },
      { search = 'CHANGED 2' },
      { keys = '<leader>s' },
    },
    assert = function(ctx)
      local staged = ctx.world:git(ctx.repo, 'diff', '--cached', '--unified=0')
      assert.is_truthy(staged:find('CHANGED 2', 1, true), 'first hunk should be staged')
      assert.is_falsy(staged:find('CHANGED 38', 1, true), 'second hunk must stay unstaged')
    end,
  })

  scenario.flow('resetting one hunk keeps the other change on disk', {
    files = { ['f.txt'] = base },
    changes = { ['f.txt'] = edited },
    steps = {
      { open = 'status' },
      { focus = { mapped = '<leader>s' } },
      { search = 'CHANGED 38' },
      { keys = '<leader>r' },
      { keys = 'y<CR>' },
    },
    assert = function(ctx)
      local content = table.concat(vim.fn.readfile(ctx.repo .. '/f.txt'), '\n')
      assert.is_truthy(content:find('CHANGED 2', 1, true), 'untouched hunk must remain')
      assert.is_falsy(content:find('CHANGED 38', 1, true), 'reset hunk must be reverted')
    end,
  })
end)

describe('scenario: external changes while a view is open', function()
  scenario.flow('status shows a file edited on disk once the editor regains focus', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    changes = { ['a.txt'] = { 'a2' } },
    steps = {
      { open = 'status' },
      { write = { path = 'b.txt', lines = { 'b2' } } },
      { cmd = 'doautocmd FocusGained' },
      { await_text = 'b.txt', settle_ms = 4000 },
    },
    expect = { screen_has = { 'a.txt', 'b.txt' } },
  })

  scenario.flow('status refreshes when git state changes outside the editor', {
    files = { ['a.txt'] = { 'a' } },
    changes = { ['a.txt'] = { 'a2' } },
    steps = {
      { open = 'status' },
      { git = { 'add', 'a.txt' } },
      { await_text = 'Staged', settle_ms = 6000 },
    },
    expect = { screen_has = { 'Staged', 'a.txt' } },
  })

  scenario.flow('rapid stage and unstage keeps git and the screen consistent', {
    files = { ['a.txt'] = { 'a' } },
    changes = { ['a.txt'] = { 'a2' } },
    steps = {
      { open = 'status' },
      { keys = 'susususu' },
      { settle = 800 },
    },
    expect = { git_status = ' M a.txt' },
  })
end)
