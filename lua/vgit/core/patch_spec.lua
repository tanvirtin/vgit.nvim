local patch = require('vgit.core.patch')

local eq = assert.are.same

describe('patch:', function()
  it('should default to semantic roles and word roles', function()
    local layout = patch.build({
      {
        type = 'diff_content',
        lines = { 'local x = 2' },
        lnum_change_map = {
          [1] = {
            type = 'add',
            word_diff = {
              { 0, 'local x = ' },
              { -1, '2' },
            },
          },
        },
        filetype = 'lua',
      },
    })

    eq('add', layout.highlights[1].role)
    eq({ { row = 0, col = 10, texts = { { '2', 'word_add' } } } }, layout.words)
  end)
end)
