local scenario = require('tests.scenario')({ it = it })

describe('scenario: live gutter', function()
  scenario.flow('an edited line gets a sign in the gutter', {
    files = { ['file.txt'] = { 'one', 'two', 'three' } },
    steps = {
      { cd = '$repo' },
      { edit = 'file.txt' },
      { write = { path = 'file.txt', lines = { 'one', 'TWO', 'three' } } },
      { cmd = 'checktime' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a gutter sign',
      },
    },
    expect = {
      signs = { { lnum = 2 } },
    },
  })

  scenario.flow('an untouched file has no gutter signs', {
    files = { ['file.txt'] = { 'one', 'two' } },
    steps = {
      { cd = '$repo' },
      { edit = 'file.txt' },
      { settle = 500 },
    },
    assert = function(ctx)
      assert.are.same(0, #ctx.observe.signs(ctx))
    end,
  })
end)
