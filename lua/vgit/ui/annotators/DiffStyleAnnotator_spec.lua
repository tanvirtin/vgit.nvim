local DiffStyleAnnotator = require('vgit.ui.annotators.DiffStyleAnnotator')

local eq = assert.are.same

describe('DiffStyleAnnotator:', function()
  local annotator

  before_each(function()
    annotator = DiffStyleAnnotator()
  end)

  describe('_annotate_header', function()
    it('should produce highlights for standard hunk header', function()
      local line = '@@ -1,3 +1,5 @@'
      local highlights = annotator:_annotate_header(line, 0)

      -- Should have at least: background, opening @@, minus range, plus range, closing @@
      assert.is_true(#highlights >= 4)

      -- First highlight should be full line background
      eq(0, highlights[1].row)
      eq('GitPatchHeader', highlights[1].hl_group)
      assert.is_true(highlights[1].line)

      -- Second highlight: opening @@
      eq(0, highlights[2].col_start)
      eq(2, highlights[2].col_end)
      eq('GitPatchHeaderMarker', highlights[2].hl_group)
    end)

    it('should highlight minus range', function()
      local line = '@@ -10,3 +20,5 @@'
      local highlights = annotator:_annotate_header(line, 5)

      local found_remove = false
      for _, hl in ipairs(highlights) do
        if hl.hl_group == 'GitPatchHeaderRemove' then
          found_remove = true
          eq(5, hl.row)
        end
      end
      assert.is_true(found_remove)
    end)

    it('should highlight plus range', function()
      local line = '@@ -10,3 +20,5 @@'
      local highlights = annotator:_annotate_header(line, 0)

      local found_add = false
      for _, hl in ipairs(highlights) do
        if hl.hl_group == 'GitPatchHeaderAdd' then found_add = true end
      end
      assert.is_true(found_add)
    end)
  end)

  describe('annotate', function()
    it('should use metadata types for classification', function()
      local lines = {
        '────────────────',
        'test.lua',
        '────────────────',
        'local x = 1',
        'local y = 2',
      }
      local line_metadata = {
        [1] = { type = 'separator' },
        [2] = { type = 'filename' },
        [3] = { type = 'separator' },
        [4] = { type = 'code', lnum_change = { type = 'add' } },
        [5] = { type = 'code', lnum_change = { type = 'remove' } },
      }

      local highlights = annotator:annotate(lines, line_metadata)

      -- Check separator highlights
      local sep_count = 0
      for _, hl in ipairs(highlights) do
        if hl.hl_group == 'GitPatchSeparator' then sep_count = sep_count + 1 end
      end
      eq(2, sep_count)

      -- Check filename highlight
      local found_filename = false
      for _, hl in ipairs(highlights) do
        if hl.hl_group == 'GitPatchFileHeader' then found_filename = true end
      end
      assert.is_true(found_filename)

      -- Check code highlights
      local found_add = false
      local found_remove = false
      for _, hl in ipairs(highlights) do
        if hl.row == 3 and hl.hl_group == 'GitSignsAddLn' then found_add = true end
        if hl.row == 4 and hl.hl_group == 'GitSignsDeleteLn' then found_remove = true end
      end
      assert.is_true(found_add)
      assert.is_true(found_remove)
    end)

    it('should handle hunk headers in metadata', function()
      local lines = { '@@ -1,3 +1,5 @@' }
      local line_metadata = {
        [1] = { type = 'code', is_header = true },
      }

      local highlights = annotator:annotate(lines, line_metadata)

      local found_header = false
      for _, hl in ipairs(highlights) do
        if hl.hl_group == 'GitPatchHeader' or hl.hl_group == 'GitPatchHeaderMarker' then found_header = true end
      end
      assert.is_true(found_header)
    end)

    it('should handle lines without metadata', function()
      local lines = { 'some line' }
      local line_metadata = {}

      local highlights = annotator:annotate(lines, line_metadata)
      eq(0, #highlights)
    end)
  end)
end)
