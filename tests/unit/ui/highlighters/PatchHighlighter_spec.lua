local PatchHighlighter = require('vgit.ui.highlighters.PatchHighlighter')

local eq = assert.are.same

describe('PatchHighlighter', function()
  local highlighter

  before_each(function()
    highlighter = PatchHighlighter()
  end)

  describe('strip_patch_prefix', function()
    it('should strip + prefix from added line', function()
      local code, prefix = highlighter:strip_patch_prefix('+added line')
      eq('added line', code)
      eq('+', prefix)
    end)

    it('should strip - prefix from removed line', function()
      local code, prefix = highlighter:strip_patch_prefix('-removed line')
      eq('removed line', code)
      eq('-', prefix)
    end)

    it('should strip space prefix from context line', function()
      local code, prefix = highlighter:strip_patch_prefix(' context line')
      eq('context line', code)
      eq(' ', prefix)
    end)

    it('should return line as-is when no patch prefix', function()
      local code, prefix = highlighter:strip_patch_prefix('@@ -1,3 +1,5 @@')
      eq('@@ -1,3 +1,5 @@', code)
      eq(nil, prefix)
    end)

    it('should handle nil input', function()
      local code, prefix = highlighter:strip_patch_prefix(nil)
      eq('', code)
      eq(nil, prefix)
    end)

    it('should handle empty string', function()
      local code, prefix = highlighter:strip_patch_prefix('')
      eq('', code)
      eq(nil, prefix)
    end)

    it('should handle line with only a prefix character', function()
      local code, prefix = highlighter:strip_patch_prefix('+')
      eq('', code)
      eq('+', prefix)
    end)

    it('should handle line with only a space prefix', function()
      local code, prefix = highlighter:strip_patch_prefix(' ')
      eq('', code)
      eq(' ', prefix)
    end)
  end)

  describe('extract_code_lines', function()
    it('should extract code lines from patch', function()
      local patch_lines = {
        '@@ -1,3 +1,5 @@',
        ' context line',
        '-removed line',
        '+added line',
      }

      local code_lines, line_mapping = highlighter:extract_code_lines(patch_lines)

      eq(4, #code_lines)
      eq('', code_lines[1]) -- header becomes empty
      eq('context line', code_lines[2])
      eq('removed line', code_lines[3])
      eq('added line', code_lines[4])

      -- Check line mapping
      assert.is_true(line_mapping[1].is_header)
      eq(1, line_mapping[1].patch_lnum)
      eq(' ', line_mapping[2].prefix)
      eq(2, line_mapping[2].patch_lnum)
      eq('-', line_mapping[3].prefix)
      eq(3, line_mapping[3].patch_lnum)
      eq('+', line_mapping[4].prefix)
      eq(4, line_mapping[4].patch_lnum)
    end)

    it('should handle empty patch', function()
      local code_lines, line_mapping = highlighter:extract_code_lines({})
      eq(0, #code_lines)
      eq({}, line_mapping)
    end)

    it('should handle multiple hunk headers', function()
      local patch_lines = {
        '@@ -1,2 +1,2 @@',
        ' line1',
        '@@ -10,2 +10,2 @@',
        ' line2',
      }

      local code_lines, line_mapping = highlighter:extract_code_lines(patch_lines)

      eq(4, #code_lines)
      assert.is_true(line_mapping[1].is_header)
      assert.is_true(line_mapping[3].is_header)
      eq('line1', code_lines[2])
      eq('line2', code_lines[4])
    end)
  end)

  describe('adjust_highlights_for_patch', function()
    it('should adjust highlight positions from code lines to patch lines', function()
      local highlights = {
        { row = 1, col_start = 0, col_end = 5, hl_group = '@keyword' },
      }
      local line_mapping = {
        [1] = { patch_lnum = 1, is_header = true },
        [2] = { patch_lnum = 2, prefix = ' ' },
      }

      local adjusted = highlighter:adjust_highlights_for_patch(highlights, line_mapping)

      eq(1, #adjusted)
      eq(1, adjusted[1].row) -- patch_lnum 2 -> row 1 (0-indexed)
      eq(1, adjusted[1].col_start) -- shifted by prefix offset
      eq(6, adjusted[1].col_end)
      eq('@keyword', adjusted[1].hl_group)
    end)

    it('should skip highlights on header lines', function()
      local highlights = {
        { row = 0, col_start = 0, col_end = 5, hl_group = '@keyword' },
      }
      local line_mapping = {
        [1] = { patch_lnum = 1, is_header = true },
      }

      local adjusted = highlighter:adjust_highlights_for_patch(highlights, line_mapping)
      eq(0, #adjusted)
    end)

    it('should handle col_end of -1 (end of line)', function()
      local highlights = {
        { row = 1, col_start = 0, col_end = -1, hl_group = '@string' },
      }
      local line_mapping = {
        [1] = { patch_lnum = 1, is_header = true },
        [2] = { patch_lnum = 2, prefix = '+' },
      }

      local adjusted = highlighter:adjust_highlights_for_patch(highlights, line_mapping)

      eq(1, #adjusted)
      eq(-1, adjusted[1].col_end)
    end)

    it('should handle empty highlights', function()
      local adjusted = highlighter:adjust_highlights_for_patch({}, {})
      eq(0, #adjusted)
    end)
  end)

  describe('parse_hunk_header', function()
    it('should parse standard hunk header with counts', function()
      local orig, curr = highlighter:parse_hunk_header('@@ -1,3 +1,5 @@')
      eq(1, orig)
      eq(1, curr)
    end)

    it('should parse hunk header with larger line numbers', function()
      local orig, curr = highlighter:parse_hunk_header('@@ -100,20 +150,25 @@')
      eq(100, orig)
      eq(150, curr)
    end)

    it('should parse hunk header without counts', function()
      local orig, curr = highlighter:parse_hunk_header('@@ -1 +1 @@')
      eq(1, orig)
      eq(1, curr)
    end)

    it('should parse hunk header with context text', function()
      local orig, curr = highlighter:parse_hunk_header('@@ -10,5 +20,8 @@ function foo()')
      eq(10, orig)
      eq(20, curr)
    end)

    it('should return defaults for nil header', function()
      local orig, curr = highlighter:parse_hunk_header(nil)
      eq(1, orig)
      eq(1, curr)
    end)

    it('should return defaults for non-matching header', function()
      local orig, curr = highlighter:parse_hunk_header('not a header')
      eq(1, orig)
      eq(1, curr)
    end)

    it('should handle single line changes', function()
      local orig, curr = highlighter:parse_hunk_header('@@ -5,1 +5,1 @@')
      eq(5, orig)
      eq(5, curr)
    end)
  end)

  describe('build_line_highlight_map', function()
    it('should build lookup map from highlights', function()
      local highlights = {
        { row = 0, col_start = 0, col_end = 5, hl_group = '@keyword' },
        { row = 0, col_start = 6, col_end = 10, hl_group = '@string' },
        { row = 2, col_start = 0, col_end = 3, hl_group = '@number' },
      }

      local map = highlighter:build_line_highlight_map(highlights)

      -- row 0 -> line 1 (1-indexed)
      eq(2, #map[1])
      eq(0, map[1][1].col_start)
      eq(5, map[1][1].col_end)
      eq('@keyword', map[1][1].hl_group)
      eq(6, map[1][2].col_start)
      eq(10, map[1][2].col_end)
      eq('@string', map[1][2].hl_group)

      -- row 2 -> line 3
      eq(1, #map[3])
      eq('@number', map[3][1].hl_group)

      -- no highlights on line 2
      eq(nil, map[2])
    end)

    it('should handle empty highlights', function()
      local map = highlighter:build_line_highlight_map({})
      eq({}, map)
    end)
  end)

  describe('map_line_highlights', function()
    it('should map highlights from source to target row', function()
      local result = {}
      local hl_map = {
        [5] = {
          { col_start = 0, col_end = 3, hl_group = '@keyword' },
          { col_start = 4, col_end = 10, hl_group = '@string' },
        },
      }

      highlighter:map_line_highlights(result, hl_map, 5, 10, 1)

      eq(2, #result)
      eq(10, result[1].row)
      eq(1, result[1].col_start) -- 0 + 1 col_offset
      eq(4, result[1].col_end) -- 3 + 1 col_offset
      eq('@keyword', result[1].hl_group)
      eq(10, result[2].row)
      eq(5, result[2].col_start)
      eq(11, result[2].col_end)
    end)

    it('should handle col_end of -1', function()
      local result = {}
      local hl_map = {
        [1] = {
          { col_start = 0, col_end = -1, hl_group = '@comment' },
        },
      }

      highlighter:map_line_highlights(result, hl_map, 1, 0, 1)

      eq(1, #result)
      eq(-1, result[1].col_end)
    end)

    it('should do nothing when source line has no highlights', function()
      local result = {}
      local hl_map = {}

      highlighter:map_line_highlights(result, hl_map, 5, 10, 1)

      eq(0, #result)
    end)

    it('should apply zero col_offset', function()
      local result = {}
      local hl_map = {
        [1] = {
          { col_start = 2, col_end = 8, hl_group = '@variable' },
        },
      }

      highlighter:map_line_highlights(result, hl_map, 1, 3, 0)

      eq(1, #result)
      eq(2, result[1].col_start)
      eq(8, result[1].col_end)
    end)
  end)

  describe('get_hunk_header_highlights', function()
    it('should produce highlights for standard hunk header', function()
      local line = '@@ -1,3 +1,5 @@'
      local highlights = highlighter:get_hunk_header_highlights(line, 0)

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
      local highlights = highlighter:get_hunk_header_highlights(line, 5)

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
      local highlights = highlighter:get_hunk_header_highlights(line, 0)

      local found_add = false
      for _, hl in ipairs(highlights) do
        if hl.hl_group == 'GitPatchHeaderAdd' then
          found_add = true
        end
      end
      assert.is_true(found_add)
    end)
  end)

  describe('get_diff_line_highlights', function()
    it('should classify diff lines correctly', function()
      local patch_lines = {
        '@@ -1,3 +1,4 @@',
        ' context',
        '-removed',
        '+added',
        '+also added',
      }

      local highlights = highlighter:get_diff_line_highlights(patch_lines)

      -- Line 1 (row 0): header
      local header_hls = {}
      for _, hl in ipairs(highlights) do
        if hl.row == 0 then header_hls[#header_hls + 1] = hl end
      end
      assert.is_true(#header_hls > 0)

      -- Line 2 (row 1): context
      local found_context = false
      for _, hl in ipairs(highlights) do
        if hl.row == 1 and hl.hl_group == 'GitPatchContext' then found_context = true end
      end
      assert.is_true(found_context)

      -- Line 3 (row 2): removed
      local found_remove = false
      for _, hl in ipairs(highlights) do
        if hl.row == 2 and hl.hl_group == 'GitSignsDeleteLn' then found_remove = true end
      end
      assert.is_true(found_remove)

      -- Line 4 (row 3): added
      local found_add = false
      for _, hl in ipairs(highlights) do
        if hl.row == 3 and hl.hl_group == 'GitSignsAddLn' then found_add = true end
      end
      assert.is_true(found_add)
    end)

    it('should handle empty patch', function()
      local highlights = highlighter:get_diff_line_highlights({})
      eq(0, #highlights)
    end)
  end)

  describe('get_diff_line_highlights_with_metadata', function()
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

      local highlights = highlighter:get_diff_line_highlights_with_metadata(lines, line_metadata)

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

      local highlights = highlighter:get_diff_line_highlights_with_metadata(lines, line_metadata)

      local found_header = false
      for _, hl in ipairs(highlights) do
        if hl.hl_group == 'GitPatchHeader' or hl.hl_group == 'GitPatchHeaderMarker' then found_header = true end
      end
      assert.is_true(found_header)
    end)

    it('should handle lines without metadata', function()
      local lines = { 'some line' }
      local line_metadata = {}

      local highlights = highlighter:get_diff_line_highlights_with_metadata(lines, line_metadata)
      eq(0, #highlights)
    end)
  end)
end)
