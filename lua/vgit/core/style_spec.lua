local style = require('vgit.core.style')

local eq = assert.are.same

describe('style:', function()
  describe('annotate', function()
    it('should mark separators, filenames and context', function()
      local lines = { '────────', 'test.lua', '────────', 'local x = 1' }
      local metadata = {
        [1] = { type = 'separator' },
        [2] = { type = 'filename' },
        [3] = { type = 'separator' },
        [4] = { type = 'code' },
      }

      local highlights = style.annotate(lines, metadata)

      eq('separator', highlights[1].role)
      eq('filename', highlights[2].role)
      eq('separator', highlights[3].role)
      eq('context', highlights[4].role)
    end)

    it('should use the change type as the role and skip void lines', function()
      local lines = { 'add', 'remove', 'void' }
      local metadata = {
        [1] = { type = 'code', lnum_change = { type = 'add' } },
        [2] = { type = 'code', lnum_change = { type = 'remove' } },
        [3] = { type = 'code', lnum_change = { type = 'void' } },
      }

      local highlights = style.annotate(lines, metadata)

      eq('add', highlights[1].role)
      eq('remove', highlights[2].role)
      eq(nil, highlights[3])
    end)

    it('should give header, marker, add and remove roles', function()
      local highlights = style.annotate({ '@@ -1,3 +1,5 @@' }, {
        [1] = { type = 'code', is_header = true },
      })

      local roles = {}
      for _, hl in ipairs(highlights) do
        roles[hl.role] = true
      end

      assert.is_true(roles.header)
      assert.is_true(roles.header_marker)
      assert.is_true(roles.header_add)
      assert.is_true(roles.header_remove)
    end)
  end)
end)
