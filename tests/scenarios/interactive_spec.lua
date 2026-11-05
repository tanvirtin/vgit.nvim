-- Interactive flows that mutate state through keymaps: bulk operations and the
-- commit buffer's cancel path.
local scenario = require('tests.scenario')({ it = it })

describe('scenario: interactive flows', function()
  scenario.flow('unstage everything with U', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    staged = { ['a.txt'] = { 'a changed' }, ['b.txt'] = { 'b changed' } },
    steps = {
      { open = 'status' },
      { keys = 'U' },
    },
    expect = {
      git_status = ' M a.txt\n M b.txt',
    },
  })

  scenario.flow('reset everything with <leader>R after confirming', {
    files = { ['file.txt'] = { 'base' } },
    changes = { ['file.txt'] = { 'changed' } },
    steps = {
      { open = 'status' },
      { keys = '<leader>R' },
      { await_text = '(y/N)' },
      { keys = 'y<CR>' },
    },
    expect = {
      git_status = '',
    },
    assert = function(ctx)
      assert.are.same({ 'base' }, vim.fn.readfile(ctx.repo .. '/file.txt'))
    end,
  })

  scenario.flow('cancelling the commit buffer with q leaves the change staged', {
    files = { ['file.txt'] = { 'base' } },
    staged = { ['file.txt'] = { 'changed' } },
    steps = {
      { open = 'status' },
      { keys = 'C' },
      { await_filetype = 'gitcommit' },
      { keys = '<Esc>q' },
    },
    expect = {
      git_status = 'M  file.txt',
    },
    assert = function(ctx)
      assert.are.same('1', ctx.world:git(ctx.repo, 'rev-list', '--count', 'HEAD'))
    end,
  })

  scenario.test('a failed commit keeps the message and reports the error', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })
    s.world:git(main, 'add', 'file.txt')

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('VGit commit')
    s.editor:await_filetype('gitcommit')

    -- A stale index.lock makes git refuse the commit.
    s.world:write(main .. '/.git/index.lock', '')

    s.editor:keys('keep this message<C-s>')
    s.editor:settle(1200)

    assert.is_truthy(s.observe.contains(s, 'keep this message'), 'the commit message should stay in the buffer')
    assert.is_truthy(s.observe.contains(s, 'index.lock'), 'the git error should be reported to the user')
    assert.are.same('1', s.world:git(main, 'rev-list', '--count', 'HEAD'))

    -- Removing the lock and confirming again commits the same message.
    s.editor:dismiss()
    vim.fn.delete(main .. '/.git/index.lock')
    s.editor:keys('<C-s>')
    s.editor:settle(1500)

    assert.are.same('keep this message', s.world:git(main, 'log', '-1', '--format=%s'))
  end)

  scenario.test('a failed commit from the status view keeps the message and reports the error', function(s)
    local main = s.world:repo('main', { ['file.txt'] = { 'base' } })
    s.world:write(main .. '/file.txt', { 'changed' })
    s.world:git(main, 'add', 'file.txt')

    s.editor:cmd('cd ' .. main)
    s.editor:cmd('VGit status')
    s.editor:await_text('Changes')
    s.editor:keys('C')
    s.editor:await_filetype('gitcommit')

    s.world:write(main .. '/.git/index.lock', '')

    s.editor:keys('status commit message<C-s>')
    s.editor:settle(1200)

    assert.is_truthy(s.observe.contains(s, 'status commit message'), 'the commit message should stay in the buffer')
    assert.is_truthy(s.observe.contains(s, 'index.lock'), 'the git error should be reported to the user')
    assert.are.same('1', s.world:git(main, 'rev-list', '--count', 'HEAD'))

    s.editor:dismiss()
    vim.fn.delete(main .. '/.git/index.lock')
    s.editor:keys('<C-s>')
    s.editor:settle(1500)

    assert.are.same('status commit message', s.world:git(main, 'log', '-1', '--format=%s'))
  end)
end)
