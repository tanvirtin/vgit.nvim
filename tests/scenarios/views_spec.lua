-- Screen-level coverage for the read-only views (log, branch, stash).
-- These assert what the user actually sees when they open each view.
local scenario = require('tests.scenario')({ it = it })

describe('scenario: views', function()
  scenario.flow('the log view lists commits with hash, message and author', {
    files = { ['file.txt'] = { 'base' } },
    steps = {
      { open = 'log' },
    },
    expect = {
      screen_has = { 'initial', 'Scenario' },
    },
  })

  scenario.flow('the branch view marks the current branch', {
    files = { ['file.txt'] = { 'base' } },
    steps = {
      { open = 'branch' },
    },
    expect = {
      screen_has = { 'main', '(current)' },
    },
  })

  scenario.flow('the stash view lists a stashed change', {
    files = { ['file.txt'] = { 'base' } },
    changes = { ['file.txt'] = { 'changed' } },
    arrange = function(ctx)
      ctx.world:git(ctx.repo, 'stash', 'push', '-m', 'wip probe')
    end,
    steps = {
      { open = 'stash' },
    },
    expect = {
      screen_has = { 'wip probe' },
    },
  })

  scenario.flow('the stash view reports when there is nothing stashed', {
    files = { ['file.txt'] = { 'base' } },
    steps = {
      { open = 'stash' },
    },
    expect = {
      screen_has = { 'No stashes found' },
    },
  })
end)
