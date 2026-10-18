local scenario = require('tests.scenario')({ it = it })

describe('scenario: stash view actions', function()
  scenario.flow('pop restores the stashed change and empties the stash list', {
    files = { ['file.txt'] = { 'base' } },
    changes = { ['file.txt'] = { 'stashed edit' } },
    stashes = { 'wip pop' },
    steps = {
      { open = 'stash' },
      { await_text = 'wip pop' },
      { focus = 'diff' },
      { keys = 'p' },
    },
    expect = {
      file = { ['file.txt'] = { 'stashed edit' } },
    },
    assert = function(ctx)
      assert.are.same('', ctx.world:git(ctx.repo, 'stash', 'list'))
    end,
  })

  scenario.flow('apply restores the change but keeps the stash entry', {
    files = { ['file.txt'] = { 'base' } },
    changes = { ['file.txt'] = { 'stashed edit' } },
    stashes = { 'wip apply' },
    steps = {
      { open = 'stash' },
      { await_text = 'wip apply' },
      { focus = 'diff' },
      { keys = 'a' },
    },
    expect = {
      file = { ['file.txt'] = { 'stashed edit' } },
    },
    assert = function(ctx)
      assert.is_truthy(ctx.world:git(ctx.repo, 'stash', 'list'):find('wip apply', 1, true))
    end,
  })
end)
