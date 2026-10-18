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
end)
