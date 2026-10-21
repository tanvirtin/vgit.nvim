local scenario = require('tests.scenario')({ it = it })

local function show(files, keymaps)
  return string.format('lua require("vgit.api").show({ files = %s, keymaps = %s })', files, keymaps or '{}')
end

describe('scenario: diff views of in-memory content', function()
  scenario.flow('one file opens in the file diff view without a repository', {
    steps = {
      {
        cmd = show(
          [[{ { filename = 'x.lua', old_lines = { 'local a = 1', 'return a' }, new_lines = { 'local a = 2', 'return a' } } }]],
          [[{ { key = 'X', handler = function() vim.g.vgit_api_hit = 1 end } }]]
        ),
      },
      { await_text = 'local a = 2' },
      { keys = 'X' },
      {
        wait_until = function(ctx)
          return ctx.editor.terminal:rpc_eval('vim.g.vgit_api_hit') == '1'
        end,
        desc = 'the custom keymap to run',
      },
      { keys = 'b' },
    },
    expect = { screen_has = { 'local a = 1', 'local a = 2', 'return a' } },
  })

  scenario.flow('several files open in the project diff view without a repository', {
    steps = {
      {
        cmd = show(
          [[{ { filename = 'x.txt', old_lines = { 'one' }, new_lines = { 'two' } }, { filename = 'y.txt', old_lines = {}, new_lines = { 'new file' } } }]]
        ),
      },
      { await_text = 'new file' },
    },
    expect = { screen_has = { 'x.txt', 'y.txt', 'one', 'two', 'new file' } },
  })

  scenario.flow('one file opens side by side when asked for the split layout', {
    steps = {
      {
        cmd = [[lua require("vgit.api").show({ layout = 'split', files = { { filename = 'x.txt', old_lines = { 'left side' }, new_lines = { 'right side' } } } })]],
      },
      { await_text = 'right side' },
    },
    expect = { screen_has = { 'left side', 'right side' } },
  })
end)
