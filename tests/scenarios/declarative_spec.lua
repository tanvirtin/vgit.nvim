-- Same user flows as status_flow_spec.lua, but expressed declaratively so the
-- arrange/act/assert intent reads top-to-bottom. This is the proof that a
-- "paint a screen, map it into an assertion" case fits in one table.
local scenario = require('tests.scenario')({ it = it })

describe('scenario: declarative flows', function()
  scenario.flow('stage a file from the status view with s', {
    files = { ['file.txt'] = { 'base' } },
    changes = { ['file.txt'] = { 'changed' } },
    steps = {
      { open = 'status' },
      { keys = 's' },
    },
    expect = {
      git_status = 'M  file.txt',
    },
  })

  scenario.flow('unstage a staged file with u', {
    files = { ['file.txt'] = { 'base' } },
    staged = { ['file.txt'] = { 'changed' } },
    steps = {
      { open = 'status' },
      { keys = 'u' },
    },
    expect = {
      git_status = ' M file.txt',
    },
  })

  scenario.flow('stage everything with S', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    changes = { ['a.txt'] = { 'a changed' }, ['b.txt'] = { 'b changed' } },
    steps = {
      { open = 'status' },
      { keys = 'S' },
    },
    expect = {
      git_status = 'M  a.txt\nM  b.txt',
    },
  })

  scenario.flow('commit through the commit buffer with C then <C-s>', {
    files = { ['file.txt'] = { 'base' } },
    staged = { ['file.txt'] = { 'changed' } },
    steps = {
      { open = 'status' },
      { keys = 'C' },
      { await_filetype = 'gitcommit' },
      { keys = 'scenario commit<C-s>' },
    },
    expect = {
      git_status = '',
    },
    assert = function(ctx)
      assert.are.same('scenario commit', ctx.world:git(ctx.repo, 'log', '-1', '--format=%s'))
    end,
  })

  scenario.flow('the diff pane toggles between staged and working content with t', {
    files = { ['file.txt'] = { 'base' } },
    staged = { ['file.txt'] = { 'staged version' } },
    changes = { ['file.txt'] = { 'working version' } },
    steps = {
      { open = 'status' },
      { snap = 'before' },
      { keys = 't' },
      { snap = 'after' },
    },
    expect = {
      screen_changed = { 'before', 'after' },
    },
  })

  scenario.flow('stashing from the status view does not spam an autocmd error', {
    files = { ['file.txt'] = { 'base' } },
    changes = { ['file.txt'] = { 'changed' } },
    steps = {
      { open = 'status' },
      { keys = 'n' },
      { settle = 3000 },
    },
    expect = {
      git_status = '',
      screen_hasnt = { 'E218' },
    },
    assert = function(ctx)
      assert.is_truthy(ctx.world:git(ctx.repo, 'stash', 'list'):find('WIP', 1, true))
    end,
  })
end)
