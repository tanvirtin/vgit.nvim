local scenario = require('tests.scenario')({ it = it })

describe('scenario: blame and history', function()
  scenario.flow('blame view shows the commit that last touched the line', {
    files = { ['file.txt'] = { 'one', 'two' } },
    history = { { message = 'touch line two', files = { ['file.txt'] = { 'one', 'TWO' } } } },
    steps = {
      { cd = '$repo' },
      { edit = 'file.txt' },
      { cursor = { 2, 1 } },
      { cmd = 'VGit blame' },
      { await_text = 'touch line two' },
    },
    expect = {
      screen_has = { 'touch line two', 'Scenario' },
    },
  })

  scenario.flow('log view lists history newest first', {
    files = { ['file.txt'] = { 'one' } },
    history = {
      { message = 'second', files = { ['file.txt'] = { 'two' } } },
      { message = 'third', files = { ['file.txt'] = { 'three' } } },
    },
    steps = { { open = 'log' }, { await_text = 'third' } },
    expect = { screen_has = { 'third', 'second', 'initial' } },
    assert = function(ctx)
      local frame = ctx.observe.frame(ctx)
      assert.is_true(frame:find('third', 1, true) < frame:find('second', 1, true))
      assert.is_true(frame:find('second', 1, true) < frame:find('initial', 1, true))
    end,
  })
end)

describe('scenario: project diff', function()
  scenario.flow('project diff lists every changed file', {
    files = { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    changes = { ['a.txt'] = { 'a2' }, ['b.txt'] = { 'b2' } },
    steps = {
      { cd = '$repo' },
      { cmd = 'VGit diff' },
      {
        await_text = 'a2',
      },
    },
    expect = { screen_has = { 'a.txt', 'b.txt', 'a2', 'b2' } },
  })
end)
