local scenario = require('tests.scenario')({ it = it })

describe('scenario: branch view', function()
  scenario.flow('selecting another branch checks it out', {
    files = { ['f.txt'] = { 'one' } },
    branches = { 'feature-x' },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit branch' },
      { await_text = 'feature-x' },
      { keys = 'feature' },
      { settle = 400 },
      { keys = '<CR>' },
      { settle = 800 },
    },
    assert = function(ctx)
      assert.are.same('feature-x', ctx.world:git(ctx.repo, 'rev-parse', '--abbrev-ref', 'HEAD'))
    end,
  })

  scenario.flow('typing an unknown name offers to create the branch', {
    files = { ['f.txt'] = { 'one' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit branch' },
      { await_text = 'main' },
      { keys = 'brand-new' },
      { settle = 400 },
      { keys = '<CR>' },
      { await_text = '(y/N)' },
      { keys = 'y<CR>' },
      { settle = 800 },
    },
    assert = function(ctx)
      assert.are.same('brand-new', ctx.world:git(ctx.repo, 'rev-parse', '--abbrev-ref', 'HEAD'))
    end,
  })

  scenario.flow('declining the create prompt leaves the branch unchanged', {
    files = { ['f.txt'] = { 'one' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit branch' },
      { await_text = 'main' },
      { keys = 'brand-new' },
      { settle = 400 },
      { keys = '<CR>' },
      { await_text = '(y/N)' },
      { keys = 'n<CR>' },
      { settle = 800 },
    },
    assert = function(ctx)
      assert.are.same('main', ctx.world:git(ctx.repo, 'rev-parse', '--abbrev-ref', 'HEAD'))
    end,
  })

  scenario.flow('checking out a branch with conflicting local changes reports an error', {
    files = { ['f.txt'] = { 'one' } },
    arrange = function(ctx)
      ctx.world:branch(ctx.repo, 'other', { checkout = true })
      ctx.world:write(ctx.repo .. '/f.txt', { 'other side' })
      ctx.world:commit(ctx.repo, 'other change')
      ctx.world:git(ctx.repo, 'checkout', '-q', 'main')
      ctx.world:write(ctx.repo .. '/f.txt', { 'local edit' })
    end,
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit branch' },
      { await_text = 'other' },
      { keys = 'other' },
      { settle = 400 },
      { keys = '<CR>' },
      { settle = 800 },
    },
    invariants = false,
    assert = function(ctx)
      assert.are.same('main', ctx.world:git(ctx.repo, 'rev-parse', '--abbrev-ref', 'HEAD'))
      assert.are.same({ 'local edit' }, vim.fn.readfile(ctx.repo .. '/f.txt'))
    end,
  })
end)

describe('scenario: log picker', function()
  scenario.flow('typing filters commits by message', {
    files = { ['f.txt'] = { 'one' } },
    history = {
      { message = 'fix login bug', files = { ['f.txt'] = { 'two' } } },
      { message = 'add dark mode', files = { ['f.txt'] = { 'three' } } },
    },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit log' },
      { await_text = 'dark mode' },
      { keys = 'login' },
      { await_no_text = 'dark mode' },
    },
    expect = { screen_has = { 'fix login bug' }, screen_hasnt = { 'add dark mode' } },
  })

  scenario.flow('selecting a commit opens its diff', {
    files = { ['f.txt'] = { 'one' } },
    history = { { message = 'change f', files = { ['f.txt'] = { 'two' } } } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit log' },
      { await_text = 'change f' },
      { keys = '<CR>' },
      { await_text = 'two' },
    },
    expect = { screen_has = { 'f.txt', 'two' } },
  })

  scenario.flow('a long history can still be filtered to a single old commit', {
    files = { ['f.txt'] = { 'one' } },
    arrange = function(ctx)
      for i = 1, 60 do
        ctx.world:write(ctx.repo .. '/f.txt', { 'v' .. i })
        ctx.world:commit(ctx.repo, i == 3 and 'needle commit' or ('filler ' .. i))
      end
    end,
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit log' },
      { await_text = 'filler 60' },
      { keys = 'needle' },
      { await_text = 'needle commit' },
    },
    expect = { screen_has = { 'needle commit' } },
  })
end)

describe('scenario: blame view navigation', function()
  local history = {
    { message = 'second version', files = { ['f.txt'] = { 'v2' } } },
    { message = 'third version', files = { ['f.txt'] = { 'v3' } } },
  }

  scenario.flow('the blame lens shows the commit that last touched the line', {
    files = { ['f.txt'] = { 'v1' } },
    history = history,
    steps = { { cd = '$repo' }, { edit = 'f.txt' }, { cmd = 'VGit blame' }, { await_text = 'third version' } },
    expect = { screen_has = { 'third version', 'Scenario' } },
  })

  scenario.flow('enter walks to the parent commit and backspace returns', {
    files = { ['f.txt'] = { 'v1' } },
    history = history,
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { cmd = 'VGit blame --screen' },
      { await_text = 'third version' },
      { snap = 'latest' },
      { keys = '<CR>' },
      { await_text = 'second version' },
      { snap = 'parent' },
      { keys = '<BS>' },
      { await_text = 'third version' },
      { snap = 'back' },
    },
    expect = { screen_changed = { 'latest', 'parent' }, screen_same = { 'latest', 'back' } },
  })

  scenario.flow('d in the blame screen shows the commit diff', {
    files = { ['f.txt'] = { 'v1' } },
    history = history,
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { cmd = 'VGit blame --screen' },
      { await_text = 'third version' },
      { keys = 'd' },
      { await_text = 'v3' },
    },
    expect = { screen_has = { 'v3' } },
  })

  scenario.flow('enter on the initial commit reports there is no parent', {
    files = { ['f.txt'] = { 'v1' } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { cmd = 'VGit blame --screen' },
      { await_text = 'initial' },
      { keys = '<CR>' },
      { settle = 600 },
    },
    expect = { screen_has = { 'initial' } },
  })

  scenario.flow('blame on an untracked file reports an error and stays usable', {
    files = { ['f.txt'] = { 'v1' } },
    untracked = { ['new.txt'] = { 'x' } },
    steps = { { cd = '$repo' }, { edit = 'new.txt' }, { cmd = 'VGit blame --screen' }, { settle = 800 } },
    invariants = false,
    assert = function(ctx)
      assert.is_truthy(ctx.editor.terminal:is_alive())
    end,
  })
end)

describe('scenario: live blame', function()
  scenario.flow('the current line shows its author and message as virtual text', {
    files = { ['f.txt'] = { 'one', 'two' } },
    history = { { message = 'touch line one', files = { ['f.txt'] = { 'ONE', 'two' } } } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { cursor = { 1, 1 } },
      {
        wait_until = function(ctx)
          for _, mark in ipairs(ctx.observe.extmarks(ctx, 1)) do
            if mark.virt_text and mark.virt_text:find('touch line one', 1, true) then return true end
          end
          return false
        end,
        desc = 'blame virtual text on line 1',
      },
    },
  })
end)

describe('scenario: worktree view', function()
  scenario.flow('the remove command deletes a worktree', {
    files = { ['f.txt'] = { 'one' } },
    arrange = function(ctx)
      ctx.feature = ctx.world:worktree(ctx.repo, 'feature')
    end,
    steps = { { cd = '$repo' }, { cmd = 'VGit worktree remove $feature' }, { settle = 1000 } },
    invariants = false,
    assert = function(ctx)
      assert.is_falsy(ctx.world:git(ctx.repo, 'worktree', 'list'):find('feature', 1, true))
    end,
  })
end)

describe('scenario: status reset', function()
  scenario.flow('r resets a changed file after confirmation', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    steps = { { open = 'status' }, { keys = 'r' }, { await_text = '(y/N)' }, { keys = 'y<CR>' }, { settle = 800 } },
    expect = { git_status = '', file = { ['f.txt'] = { 'one' } } },
  })

  scenario.flow('declining the reset keeps the change', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    steps = { { open = 'status' }, { keys = 'r' }, { await_text = '(y/N)' }, { keys = 'n<CR>' }, { settle = 800 } },
    expect = { git_status = ' M f.txt', file = { ['f.txt'] = { 'two' } } },
  })

  scenario.flow('r on an untracked file removes it after confirmation', {
    files = { ['f.txt'] = { 'one' } },
    untracked = { ['junk.txt'] = { 'x' } },
    steps = { { open = 'status' }, { keys = 'r' }, { await_text = '(y/N)' }, { keys = 'y<CR>' }, { settle = 800 } },
    expect = { git_status = '' },
  })
end)
