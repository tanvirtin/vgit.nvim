local scenario = require('tests.scenario')({ it = it })
local World = require('tests.scenario.world')

local function has_signs(count)
  return function(ctx)
    return #ctx.observe.signs(ctx) == count
  end
end

describe('scenario: live gutter tracks the buffer', function()
  scenario.flow('typing in the buffer without saving adds a sign', {
    files = { ['f.txt'] = { 'one', 'two', 'three' } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { cursor = { 2, 1 } },
      { keys = 'ccchanged<Esc>' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a sign for the unsaved edit',
      },
    },
    expect = { signs = { { lnum = 2 } } },
  })

  scenario.flow('undoing the edit removes the sign', {
    files = { ['f.txt'] = { 'one', 'two', 'three' } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { cursor = { 2, 1 } },
      { keys = 'ccchanged<Esc>' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a sign',
      },
      { keys = 'u' },
      { wait_until = has_signs(0), desc = 'no signs after undo' },
    },
  })

  scenario.flow('deleting a line shows a removed marker', {
    files = { ['f.txt'] = { 'one', 'two', 'three' } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { cursor = { 2, 1 } },
      { keys = 'dd' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a sign for the removed line',
      },
    },
  })

  scenario.flow('adding lines at the end of the file shows signs', {
    files = { ['f.txt'] = { 'one' } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      { keys = 'Go' },
      { keys = 'added line<Esc>' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a sign for the added line',
      },
    },
    expect = { signs = { { lnum = 2 } } },
  })

  scenario.flow('staging the buffer clears its signs', {
    files = { ['f.txt'] = { 'one', 'two' } },
    changes = { ['f.txt'] = { 'one', 'TWO' } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a sign',
      },
      { cmd = 'lua require("vgit").buffer_stage()' },
      { wait_until = has_signs(0), desc = 'signs cleared after staging' },
    },
  })

  scenario.flow('committing outside the editor clears the signs', {
    files = { ['f.txt'] = { 'one', 'two' } },
    changes = { ['f.txt'] = { 'one', 'TWO' } },
    steps = {
      { cd = '$repo' },
      { edit = 'f.txt' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a sign',
      },
      { git = { 'commit', '-q', '-am', 'external commit' } },
      { wait_until = has_signs(0), desc = 'signs cleared after an external commit', settle_ms = 8000 },
    },
  })

  scenario.flow('a file outside any repository gets no signs and no errors', {
    arrange = function(ctx)
      ctx.repo = ctx.world.root
      ctx.world:write(ctx.world.root .. '/loose.txt', { 'x' })
    end,
    steps = { { cd = '$repo' }, { edit = 'loose.txt' }, { keys = 'Ochange<Esc>' }, { settle = 800 } },
    assert = function(ctx)
      assert.are.same(0, #ctx.observe.signs(ctx))
    end,
  })

  scenario.flow('a large file still gets signs for an edit', {
    files = { ['big.txt'] = World.numbered_lines(8000, 'line ') },
    timeout = 25000,
    steps = {
      { cd = '$repo' },
      { edit = 'big.txt' },
      { cursor = { 4000, 1 } },
      { keys = 'ccedited<Esc>' },
      {
        wait_until = function(ctx)
          return #ctx.observe.signs(ctx) > 0
        end,
        desc = 'a sign in a large file',
        settle_ms = 8000,
      },
    },
    expect = { signs = { { lnum = 4000 } } },
  })

  scenario.flow('an untracked new file gets signs for all its lines', {
    files = { ['a.txt'] = { 'a' } },
    untracked = { ['new.txt'] = { 'x', 'y', 'z' } },
    steps = {
      { cd = '$repo' },
      { edit = 'new.txt' },
      { settle = 1000 },
    },
    assert = function(ctx)
      assert.is_true(#ctx.observe.signs(ctx) >= 1, 'an untracked file should show added-line signs')
    end,
  })
end)

describe('scenario: configuration', function()
  scenario.flow('a custom status keymap replaces the default', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    config = { settings = { status_diff_view = { keymaps = { stage = { key = 'a' } } } } },
    steps = { { open = 'status' }, { keys = 'a' } },
    expect = { git_status = 'M  f.txt' },
  })

  scenario.flow('the default key no longer works after it is remapped', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    config = { settings = { status_diff_view = { keymaps = { stage = { key = 'a' } } } } },
    steps = { { open = 'status' }, { keys = 's' } },
    invariants = false,
    expect = { git_status = ' M f.txt' },
  })

  scenario.flow('an unknown config key does not break setup', {
    files = { ['f.txt'] = { 'one' } },
    changes = { ['f.txt'] = { 'two' } },
    config = { settings = { not_a_real_setting = { x = 1 } } },
    steps = { { open = 'status' } },
    expect = { screen_has = { 'f.txt' } },
  })

  scenario.flow('live gutter disabled in settings shows no signs', {
    files = { ['f.txt'] = { 'one', 'two' } },
    changes = { ['f.txt'] = { 'one', 'TWO' } },
    config = { settings = { live_gutter = { enabled = false } } },
    steps = { { cd = '$repo' }, { edit = 'f.txt' }, { settle = 1200 } },
    assert = function(ctx)
      assert.are.same(0, #ctx.observe.signs(ctx))
    end,
  })
end)
