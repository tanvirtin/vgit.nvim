local scenario = require('tests.scenario')({ it = it })
local World = require('tests.scenario.world')

local user_config = {
  keymaps = {
    ['n <leader>hs'] = 'buffer_hunk_stage',
    ['n <leader>hr'] = 'buffer_hunk_reset',
    ['n <leader>hj'] = 'hunk_down',
  },
}

describe('journey:', function()
  scenario.flow('edit a file, stage one hunk from the buffer, commit it and find it in log and blame', {
    files = { ['app.txt'] = World.numbered_lines(40, 'line ') },
    config = user_config,
    timeout = 45000,
    steps = {
      { cd = '$repo' },
      { edit = 'app.txt' },
      { keys = '2Gccfirst change<Esc>' },
      { keys = '38Gccsecond change<Esc>' },
      { cmd = 'write' },
      { expect = { git_status = ' M app.txt', signs = { { lnum = 2 }, { lnum = 38 } } } },

      { keys = 'gg' },
      { keys = '<leader>hj' },
      { expect = { cursor_line = 2 } },
      { keys = '38G' },
      { keys = '<leader>hs' },
      {
        expect = {
          assert = function(ctx)
            local staged = ctx.world:git(ctx.repo, 'diff', '--cached')
            assert.is_truthy(staged:find('second change', 1, true), 'line 38 should be staged')
            assert.is_falsy(staged:find('first change', 1, true), 'line 2 should stay unstaged')
          end,
        },
      },

      { cmd = 'VGit status' },
      { expect = { screen_has = { 'Staged Changes', 'Changes', 'app.txt' } } },
      { keys = 'C' },
      { keys = 'stage the second change<C-s>' },
      { expect = { git_log = { 'stage the second change', 'initial' }, git_status = ' M app.txt' } },

      { cmd = 'VGit log' },
      { expect = { screen_has = { 'stage the second change' } } },
      { keys = '<Esc>' },

      { edit = 'app.txt' },
      { keys = '38G' },
      { cmd = 'VGit blame' },
      { expect = { screen_has = { 'stage the second change' } } },
    },
  })

  scenario.flow('commit from the command line, then carry on with another command', {
    files = { ['a.txt'] = { 'one' } },
    staged = { ['a.txt'] = { 'two' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit commit' },
      { keys = 'from the command line<C-s>' },
      { expect = { git_log = { 'from the command line', 'initial' } } },
      { cmd = 'VGit log' },
      { expect = { screen_has = { 'from the command line' } } },
    },
  })

  scenario.flow('create a branch from the picker, commit on it, and switch back, typing fast', {
    files = { ['a.txt'] = { 'one' } },
    timeout = 45000,
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit branch' },
      { await_text = 'main' },
      { keys = 'feature-login<CR>' },
      { await_text = '(y/N)' },
      { keys = 'y<CR>' },
      {
        expect = {
          assert = function(ctx)
            assert.are.same('feature-login', ctx.world:git(ctx.repo, 'rev-parse', '--abbrev-ref', 'HEAD'))
          end,
        },
      },

      { edit = 'a.txt' },
      { keys = 'ccon the branch<Esc>' },
      { cmd = 'write' },
      { cmd = 'VGit status' },
      { expect = { screen_has = { 'a.txt' } } },
      { keys = 'S' },
      { expect = { git_status = 'M  a.txt' } },
      { keys = 'C' },
      { keys = 'work on the branch<C-s>' },
      { expect = { git_log = { 'work on the branch', 'initial' } } },

      { cmd = 'VGit branch' },
      { await_text = 'feature-login' },
      { keys = 'main<CR>' },
      {
        expect = {
          file = { ['a.txt'] = { 'one' } },
          assert = function(ctx)
            assert.are.same('main', ctx.world:git(ctx.repo, 'rev-parse', '--abbrev-ref', 'HEAD'))
          end,
        },
      },
    },
  })
end)
