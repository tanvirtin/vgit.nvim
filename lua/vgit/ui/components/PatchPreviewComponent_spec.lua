local ui_helper = require('tests.helpers.ui')
local PatchLineBuilder = require('vgit.ui.components.PatchLineBuilder')

local eq = assert.are.same

-- Unmounted helper: uses the real constructor which sets up annotators, viewport tracking, etc.
-- Supports optional state overrides applied after construction.
local function create_patch_preview(overrides)
  local PatchPreviewComponent = require('vgit.ui.components.PatchPreviewComponent')
  overrides = overrides or {}

  local component = PatchPreviewComponent(overrides.props or {})
  for k, v in pairs(overrides.state or {}) do
    component.state[k] = v
  end
  return component
end

-- Mounted helper for tests that interact with the real element
local function create_mounted_patch_preview(overrides)
  local PatchPreviewComponent = require('vgit.ui.components.PatchPreviewComponent')
  overrides = overrides or {}

  local component = PatchPreviewComponent(overrides.props or {})
  ui_helper.mount({ component = component, mode = 'popup', width = 80, height = 40 })

  -- Apply state overrides
  for k, v in pairs(overrides.state or {}) do
    component.state[k] = v
  end

  -- Populate buffer with dummy lines so extmarks work
  local dummy = {}
  for i = 1, 30 do
    dummy[i] = ''
  end
  component._element:set_lines(dummy)

  -- Reset viewport state for a clean test baseline
  component._viewport_dirty = true
  component._last_top = nil
  component._last_bot = nil

  return component
end

describe('PatchPreviewComponent:', function()
  after_each(ui_helper.cleanup_ui)

  describe('build_patch_lines_from_entries', function()
    it('should build lines from file_header entries', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
        },
      }

      local lines, line_metadata, file_sections, marks = PatchLineBuilder.build(entries)

      -- File header produces: separator, filename, separator
      eq(3, #lines)
      assert.is_truthy(lines[1]:match('─'))
      eq('test.lua', lines[2])
      assert.is_truthy(lines[3]:match('─'))

      eq('separator', line_metadata[1].type)
      eq('filename', line_metadata[2].type)
      eq('test.lua', line_metadata[2].filename)
      eq('separator', line_metadata[3].type)

      eq(0, #marks)
    end)

    it('should build lines from hunk entries', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
        },
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,3 +1,4 @@',
            diff = {
              ' context line',
              '-removed line',
              '+added line',
              '+new line',
            },
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local lines, line_metadata, file_sections, marks = PatchLineBuilder.build(entries)

      -- 3 (file header) + 1 (hunk header) + 4 (diff lines) = 8
      -- trailing blank is removed
      eq(8, #lines)

      -- Check hunk header
      eq('@@ -1,3 +1,4 @@', lines[4])
      eq('code', line_metadata[4].type)
      assert.is_true(line_metadata[4].is_header)

      -- Check diff lines (prefixes stripped)
      eq('context line', lines[5])
      eq('removed line', lines[6])
      eq('added line', lines[7])
      eq('new line', lines[8])

      -- Check lnum_change metadata
      eq(nil, line_metadata[5].lnum_change) -- context
      eq('remove', line_metadata[6].lnum_change.type)
      eq('add', line_metadata[7].lnum_change.type)
      eq('add', line_metadata[8].lnum_change.type)

      -- Check marks (navigation markers)
      eq(1, #marks)
      eq(4, marks[1].top) -- 1-indexed start of hunk (header line)
      assert.is_true(marks[1].bot >= marks[1].top)
    end)

    it('should handle multiple hunks and files', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'a.lua',
          filetype = 'lua',
        },
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,1 +1,2 @@',
            diff = { ' line1', '+line2' },
          },
          filetype = 'lua',
          filename = 'a.lua',
        },
        {
          type = 'hunk',
          hunk = {
            header = '@@ -10,1 +11,1 @@',
            diff = { '-old', '+new' },
          },
          filetype = 'lua',
          filename = 'a.lua',
        },
        {
          type = 'file_header',
          filename = 'b.lua',
          filetype = 'lua',
        },
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,1 +1,1 @@',
            diff = { '-x', '+y' },
          },
          filetype = 'lua',
          filename = 'b.lua',
        },
      }

      local lines, line_metadata, file_sections, marks = PatchLineBuilder.build(entries)

      -- Should have 3 marks (3 hunks)
      eq(3, #marks)

      -- Should have 2 file sections
      assert.is_true(#file_sections >= 1)

      -- All marks should have valid top/bot
      for _, mark in ipairs(marks) do
        assert.is_true(mark.top >= 1)
        assert.is_true(mark.bot >= mark.top)
      end
    end)

    it('should handle diff_content entries', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
        },
        {
          type = 'diff_content',
          lines = { 'local x = 1', 'local y = 2' },
          lnum_change_map = {
            [1] = { type = 'add' },
          },
          filetype = 'lua',
        },
      }

      local lines, line_metadata = PatchLineBuilder.build(entries)

      -- Find the diff content lines
      local found_code = false
      for i, meta in pairs(line_metadata) do
        if meta.type == 'code' and meta.filetype == 'lua' then found_code = true end
      end
      assert.is_true(found_code)
    end)

    it('should handle empty entries', function()
      local component = create_patch_preview({})
      local lines, line_metadata, file_sections, marks = PatchLineBuilder.build({})

      eq(0, #lines)
      eq(0, #marks)
    end)

    it('should handle nil entries', function()
      local component = create_patch_preview({})
      local lines, line_metadata, file_sections, marks = PatchLineBuilder.build(nil)

      eq(0, #lines)
      eq(0, #marks)
    end)

    it('should strip trailing blank line', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
        },
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,1 +1,1 @@',
            diff = { '-old' },
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local lines = PatchLineBuilder.build(entries)

      -- Last line should not be empty (trailing blank removed)
      assert.are_not.equal('', lines[#lines])
    end)
  end)

  describe('line numbers from build_patch_lines_from_entries', function()
    it('should compute line numbers for unified diff', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
        },
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,3 +1,4 @@',
            diff = {
              ' context',
              '-removed',
              '+added',
              '+new_added',
            },
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local lines, _, _, _, line_numbers = PatchLineBuilder.build(entries)

      eq(#lines, #line_numbers)

      -- Separators and filename: no line number (just spaces)
      eq('GitLineNr', line_numbers[1].hl)
      eq('GitLineNr', line_numbers[2].hl)
      eq('GitLineNr', line_numbers[3].hl)

      -- Hunk header
      eq('GitPatchHeader', line_numbers[4].hl)

      -- Context line: current line 1
      eq('GitLineNr', line_numbers[5].hl)
      assert.is_truthy(line_numbers[5].text:match('%d'))

      -- Removed line: original line number with delete highlight
      eq('GitSignsDelete', line_numbers[6].hl)

      -- Added lines: current line numbers with add highlight
      eq('GitSignsAdd', line_numbers[7].hl)
      eq('GitSignsAdd', line_numbers[8].hl)
    end)

    it('should return empty line numbers for empty entries', function()
      local component = create_patch_preview({})
      local _, _, _, _, line_numbers = PatchLineBuilder.build({})
      eq(0, #line_numbers)
    end)

    it('should reset counters at each hunk header', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
        },
        {
          type = 'hunk',
          hunk = {
            header = '@@ -10,1 +20,1 @@',
            diff = {
              ' context',
            },
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local _, _, _, _, line_numbers = PatchLineBuilder.build(entries)

      -- Context line is at index 5 (3 file header lines + 1 hunk header + 1 context)
      -- Should show line 20 (current start from hunk header)
      assert.is_truthy(line_numbers[5].text:match('20'))
    end)

    it('should produce GitLineNr for non-code lines', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
        },
      }

      local _, _, _, _, line_numbers = PatchLineBuilder.build(entries)

      -- All 3 file header lines should be GitLineNr
      for i = 1, #line_numbers do
        eq('GitLineNr', line_numbers[i].hl)
      end
    end)
  end)

  describe('find_adjacent_mark_index', function()
    it('should find next mark when cursor is before first mark', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component:set_lnum(1)

      local idx = component:find_adjacent_mark_index('next')
      eq(1, idx)
    end)

    it('should find next mark when cursor is inside a mark', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component:set_lnum(7)

      local idx = component:find_adjacent_mark_index('next')
      eq(2, idx) -- next after current mark (index 1)
    end)

    it('should wrap to 1 when at last mark going next', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component:set_lnum(25)

      local idx = component:find_adjacent_mark_index('next')
      eq(1, idx) -- wraps to first
    end)

    it('should find previous mark when cursor is after last mark', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component:set_lnum(25)

      local idx = component:find_adjacent_mark_index('prev')
      eq(2, idx) -- last mark
    end)

    it('should find previous mark when cursor is inside a mark', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component:set_lnum(17)

      local idx = component:find_adjacent_mark_index('prev')
      eq(1, idx) -- previous mark (index 2 - 1)
    end)

    it('should wrap to last mark when before first mark going prev', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component:set_lnum(1)

      local idx = component:find_adjacent_mark_index('prev')
      eq(2, idx) -- wraps to last
    end)

    it('should return nil for empty marks', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
        },
      })
      component:set_lnum(1)

      local idx = component:find_adjacent_mark_index('next')
      eq(nil, idx)
    end)

    it('should find next mark when cursor is between marks', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
            { top = 25, bot = 30 },
          },
        },
      })
      component:set_lnum(12)

      local idx = component:find_adjacent_mark_index('next')
      eq(2, idx) -- next mark after gap
    end)

    it('should find prev mark when cursor is between marks', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
            { top = 25, bot = 30 },
          },
        },
      })
      component:set_lnum(22)

      local idx = component:find_adjacent_mark_index('prev')
      eq(2, idx)
    end)
  end)

  describe('get_initial_state', function()
    it('should include viewport rendering state fields', function()
      local component = create_patch_preview({})
      local state = component:get_initial_state()

      eq({}, state._diff_hl_map)
      eq({}, state._syntax_hl_map)
      eq({}, state._line_numbers)
    end)
  end)

  describe('_build_highlight_map', function()
    it('should build a row-indexed map from highlights', function()
      local component = create_patch_preview({})
      local highlights = {
        { row = 0, hl_group = 'A', line = true },
        { row = 0, hl_group = 'B', col_start = 0, col_end = 5 },
        { row = 2, hl_group = 'C', line = true },
      }

      local map = component:_build_highlight_map(highlights)

      eq(2, #map[0])
      eq('A', map[0][1].hl_group)
      eq('B', map[0][2].hl_group)
      eq(1, #map[2])
      eq('C', map[2][1].hl_group)
      eq(nil, map[1])
    end)

    it('should return empty map for empty highlights', function()
      local component = create_patch_preview({})
      local map = component:_build_highlight_map({})
      eq({}, map)
    end)
  end)

  describe('render_viewport', function()
    it('should render line numbers and highlights for visible range', function()
      local lnum_calls = {}
      local hl_calls = {}
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {
            [0] = { { row = 0, hl_group = 'GitSignsAddLn', line = true } },
            [1] = { { row = 1, hl_group = 'GitSignsDeleteLn', line = true } },
          },
          _syntax_hl_map = {
            [0] = { { row = 0, hl_group = '@keyword', col_start = 0, col_end = 5 } },
          },
          _line_numbers = {
            { text = '  1 ', hl = 'GitLineNr' },
            { text = '  2 ', hl = 'GitSignsDelete' },
            { text = '  3 ', hl = 'GitSignsAdd' },
          },
        },
      })

      local orig_lnum = component._element.place_extmark_lnum
      component._element.place_extmark_lnum = function(self_el, opts)
        lnum_calls[#lnum_calls + 1] = opts
        return orig_lnum(self_el, opts)
      end

      local orig_hl = component._element.place_extmark_highlight
      component._element.place_extmark_highlight = function(self_el, opts)
        hl_calls[#hl_calls + 1] = opts
        return orig_hl(self_el, opts)
      end

      -- Render rows 0-1 (visible viewport)
      component:render_viewport(0, 1)

      -- Should render 2 line numbers (rows 0 and 1)
      eq(2, #lnum_calls)
      eq(0, lnum_calls[1].row)
      eq('  1 ', lnum_calls[1].text)
      eq(1, lnum_calls[2].row)
      eq('  2 ', lnum_calls[2].text)

      -- Should render 1 diff hl (row 0 line) + 1 diff hl (row 1 line) + 1 syntax hl (row 0)
      eq(3, #hl_calls)
    end)

    it('should handle empty state gracefully', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {},
          _syntax_hl_map = {},
          _line_numbers = {},
        },
      })

      -- Should not error
      component:render_viewport(0, 10)
    end)
  end)

  describe('viewport dirty tracking', function()
    it('should skip render_viewport when viewport is unchanged', function()
      local hl_calls = {}
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {
            [0] = { { row = 0, hl_group = 'GitSignsAddLn', line = true } },
          },
          _syntax_hl_map = {},
          _line_numbers = {
            { text = '  1 ', hl = 'GitLineNr' },
          },
        },
      })

      local orig_hl = component._element.place_extmark_highlight
      component._element.place_extmark_highlight = function(self_el, opts)
        hl_calls[#hl_calls + 1] = opts
        return orig_hl(self_el, opts)
      end

      -- First call should render
      component:render_viewport(0, 0)
      local first_count = #hl_calls

      -- Second call with same range should skip
      component:render_viewport(0, 0)
      eq(first_count, #hl_calls)
    end)

    it('should re-render when viewport range changes', function()
      local hl_calls = {}
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {
            [0] = { { row = 0, hl_group = 'GitSignsAddLn', line = true } },
            [1] = { { row = 1, hl_group = 'GitSignsDeleteLn', line = true } },
          },
          _syntax_hl_map = {},
          _line_numbers = {
            { text = '  1 ', hl = 'GitLineNr' },
            { text = '  2 ', hl = 'GitLineNr' },
          },
        },
      })

      local orig_hl = component._element.place_extmark_highlight
      component._element.place_extmark_highlight = function(self_el, opts)
        hl_calls[#hl_calls + 1] = opts
        return orig_hl(self_el, opts)
      end

      component:render_viewport(0, 0)
      local first_count = #hl_calls

      -- Different range should render
      component:render_viewport(0, 1)
      assert.is_true(#hl_calls > first_count)
    end)

    it('should re-render after _viewport_dirty is set', function()
      local hl_calls = {}
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {
            [0] = { { row = 0, hl_group = 'GitSignsAddLn', line = true } },
          },
          _syntax_hl_map = {},
          _line_numbers = {
            { text = '  1 ', hl = 'GitLineNr' },
          },
        },
      })

      local orig_hl = component._element.place_extmark_highlight
      component._element.place_extmark_highlight = function(self_el, opts)
        hl_calls[#hl_calls + 1] = opts
        return orig_hl(self_el, opts)
      end

      component:render_viewport(0, 0)
      local first_count = #hl_calls

      -- Mark dirty, same range should re-render
      component._viewport_dirty = true
      component:render_viewport(0, 0)
      assert.is_true(#hl_calls > first_count)
    end)

    it('should clear highlights before re-rendering viewport', function()
      local clear_called = 0
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {},
          _syntax_hl_map = {},
          _line_numbers = {},
        },
      })

      local orig_clear = component._element.clear_extmark_highlights
      component._element.clear_extmark_highlights = function(self_el, ...)
        clear_called = clear_called + 1
        return orig_clear(self_el, ...)
      end

      component:render_viewport(0, 5)
      eq(1, clear_called)

      -- Change range to trigger re-render
      component:render_viewport(0, 10)
      eq(2, clear_called)
    end)
  end)

  describe('forward', function()
    it('should delegate place_extmark_highlight to element when valid', function()
      local called_with = nil
      local component = create_mounted_patch_preview({})
      local orig = component._element.place_extmark_highlight
      component._element.place_extmark_highlight = function(self_el, opts)
        called_with = opts
        return 99
      end

      local result = component:place_extmark_highlight({ hl = 'Test', row = 0 })
      eq(99, result)
      eq({ hl = 'Test', row = 0 }, called_with)
    end)

    it('should return nil for place_extmark_highlight when element is nil', function()
      local component = create_patch_preview({})
      local result = component:place_extmark_highlight({ hl = 'Test' })
      assert.is_nil(result)
    end)
  end)

  describe('with_element', function()
    it('should return default for get_lines when element is nil', function()
      local component = create_patch_preview({
        state = { lines = { 'x', 'y' }, line_metadata = {}, marks = {} },
      })

      eq({ 'x', 'y' }, component:get_lines())
    end)

    it('should return default for get_cursor when element is nil', function()
      local component = create_patch_preview({})
      eq({ 1, 1 }, component:get_cursor())
    end)

    it('should return default for get_lnum when element is nil', function()
      local component = create_patch_preview({})
      eq(1, component:get_lnum())
    end)

    it('should return default for get_line_count when element is nil', function()
      local component = create_patch_preview({})
      eq(0, component:get_line_count())
    end)

    it('should return false for is_valid when element is nil', function()
      local component = create_patch_preview({})
      assert.is_false(component:is_valid())
    end)

    it('should return true for is_valid when element is valid', function()
      local component = create_mounted_patch_preview({})
      assert.is_truthy(component:is_valid())
    end)

    it('should return self for chaining on void methods', function()
      local component = create_patch_preview({})
      eq(component, component:set_cursor({ 1, 0 }))
      eq(component, component:enable_cursorline())
      eq(component, component:disable_cursorline())
    end)
  end)

  describe('process_diff_file mark remapping', function()
    it('should produce marks within buffer line bounds for a single-hunk file', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = { 'line 1', 'line 2', 'old line' },
          current_lines = { 'line 1', 'line 2', 'new line', 'line 4', 'line 5' },
          diff = {
            lines = {
              'line 1',
              'line 2',
              'old line',
              'new line',
              'line 4',
              'line 5',
            },
            marks = {
              { top = 3, bot = 4 },
            },
            lnum_changes = {
              { lnum = 3, type = 'remove' },
              { lnum = 4, type = 'add' },
            },
          },
        },
      }

      local lines, _, _, marks = PatchLineBuilder.build(entries)

      eq(1, #marks)
      assert.is_true(marks[1].top >= 1)
      assert.is_true(marks[1].bot <= #lines)
      assert.is_true(marks[1].top <= marks[1].bot)
    end)

    it('should remap marks to lines that contain actual changes', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
          diff = {
            lines = {
              'line 1',
              'line 2',
              'old line',
              'new line',
              'line 4',
              'line 5',
            },
            marks = {
              { top = 3, bot = 4 },
            },
            lnum_changes = {
              { lnum = 3, type = 'remove' },
              { lnum = 4, type = 'add' },
            },
          },
        },
      }

      local _, line_metadata, _, marks = PatchLineBuilder.build(entries)

      local mark = marks[1]
      local mark_has_change = false
      for lnum = mark.top, mark.bot do
        local meta = line_metadata[lnum]
        if meta and meta.lnum_change and (meta.lnum_change.type == 'remove' or meta.lnum_change.type == 'add') then
          mark_has_change = true
          break
        end
      end
      assert.is_true(mark_has_change)
    end)

    it('should produce ascending non-overlapping marks for two far-apart hunks', function()
      local component = create_patch_preview({})

      local display_lines = {}
      for i = 1, 20 do
        display_lines[i] = 'line ' .. i
      end
      display_lines[3] = 'old line 3'
      display_lines[4] = 'new line 3'
      display_lines[17] = 'old line 17'
      display_lines[18] = 'new line 18'

      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
          diff = {
            lines = display_lines,
            marks = {
              { top = 3, bot = 4 },
              { top = 17, bot = 18 },
            },
            lnum_changes = {
              { lnum = 3, type = 'remove' },
              { lnum = 4, type = 'add' },
              { lnum = 17, type = 'remove' },
              { lnum = 18, type = 'add' },
            },
          },
        },
      }

      local lines, _, _, marks = PatchLineBuilder.build(entries)

      eq(2, #marks)
      assert.is_true(marks[1].bot < marks[2].top)
      assert.is_true(marks[1].top >= 1)
      assert.is_true(marks[2].bot <= #lines)
      assert.is_true(marks[1].top < marks[2].top)
    end)

    it('should produce marks from two files that are non-overlapping and ascending', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'a.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
          diff = {
            lines = { 'a1', 'a2', 'a3' },
            marks = { { top = 2, bot = 3 } },
            lnum_changes = {
              { lnum = 2, type = 'remove' },
              { lnum = 3, type = 'add' },
            },
          },
        },
        {
          type = 'diff_file',
          filename = 'b.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
          diff = {
            lines = { 'b1', 'b2', 'b3' },
            marks = { { top = 2, bot = 3 } },
            lnum_changes = {
              { lnum = 2, type = 'remove' },
              { lnum = 3, type = 'add' },
            },
          },
        },
      }

      local lines, _, _, marks = PatchLineBuilder.build(entries)

      eq(2, #marks)
      assert.is_true(marks[1].bot < marks[2].top)
      assert.is_true(marks[1].top >= 1)
      assert.is_true(marks[2].bot <= #lines)
    end)

    it('should insert gap header between non-adjacent visible ranges', function()
      local component = create_patch_preview({})

      local display_lines = {}
      for i = 1, 20 do
        display_lines[i] = 'line ' .. i
      end
      display_lines[3] = 'old 3'
      display_lines[4] = 'new 3'
      display_lines[17] = 'old 17'
      display_lines[18] = 'new 18'

      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
          diff = {
            lines = display_lines,
            marks = {
              { top = 3, bot = 4 },
              { top = 17, bot = 18 },
            },
            lnum_changes = {
              { lnum = 3, type = 'remove' },
              { lnum = 4, type = 'add' },
              { lnum = 17, type = 'remove' },
              { lnum = 18, type = 'add' },
            },
          },
        },
      }

      local _, line_metadata, _, marks = PatchLineBuilder.build(entries)

      eq(2, #marks)

      -- Both marks should point to lines that have changes
      for _, mark in ipairs(marks) do
        local has_change = false
        for lnum = mark.top, mark.bot do
          local meta = line_metadata[lnum]
          if meta and meta.lnum_change and (meta.lnum_change.type == 'remove' or meta.lnum_change.type == 'add') then
            has_change = true
            break
          end
        end
        assert.is_true(has_change)
      end

      -- There should be a hunk header in the gap between marks
      local has_gap_header = false
      for lnum = marks[1].bot + 1, marks[2].top - 1 do
        local meta = line_metadata[lnum]
        if meta and meta.is_header then
          has_gap_header = true
          break
        end
      end
      assert.is_true(has_gap_header)
    end)
  end)

  describe('diff_file data consistency with real Diff', function()
    local Diff = require('vgit.core.diff.Diff')
    local GitHunk = require('vgit.git.GitHunk')
    local invariants = require('tests.helpers.diff_invariants')

    local function make_hunk(header, diff_lines)
      local hunk = GitHunk(header)
      for _, line in ipairs(diff_lines or {}) do
        hunk:push(line)
      end
      return hunk
    end

    it('should produce valid patch marks from a real unified Diff', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff():generate_unified({ hunk }, { 'a', 'new', 'c' })

      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = { 'a', 'old', 'c' },
          current_lines = { 'a', 'new', 'c' },
          diff = diff,
        },
      }

      local lines, _, _, marks = PatchLineBuilder.build(entries)

      assert.is_true(#marks > 0, 'should produce at least one mark')
      invariants.assert_patch_marks(marks, #lines)
    end)

    it('should produce valid patch marks from multi-hunk real Diff', function()
      local hunk1 = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local hunk2 = make_hunk('@@ -4,1 +6,1 @@', { '-old', '+changed' })
      local diff = Diff():generate_unified({ hunk1, hunk2 }, { 'new1', 'new2', 'a', 'b', 'c', 'changed' })

      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = { 'a', 'b', 'c', 'old' },
          current_lines = { 'new1', 'new2', 'a', 'b', 'c', 'changed' },
          diff = diff,
        },
      }

      local lines, _, _, marks = PatchLineBuilder.build(entries)

      assert.is_true(#marks > 0)
      invariants.assert_patch_marks(marks, #lines)
    end)

    it('should preserve word_diff through to line_metadata', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = { 'hello world' },
          current_lines = { 'hello earth' },
          diff = {
            lines = { 'hello world', 'hello earth' },
            marks = { { top = 1, bot = 2 } },
            lnum_changes = {
              { lnum = 1, type = 'remove', word_diff = { { 0, 'hello ' }, { -1, 'world' } } },
              { lnum = 2, type = 'add', word_diff = { { 0, 'hello ' }, { 1, 'earth' } } },
            },
          },
        },
      }

      local _, line_metadata = PatchLineBuilder.build(entries)

      local found_word_diff = false
      for _, meta in pairs(line_metadata) do
        if meta.lnum_change and meta.lnum_change.word_diff then
          found_word_diff = true
          invariants.assert_word_diff_shape({ meta.lnum_change })
        end
      end
      assert.is_true(found_word_diff, 'word_diff should be preserved in line_metadata')
    end)

    it('should produce line_numbers with same count as lines', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff():generate_unified({ hunk }, { 'a', 'new', 'c' })

      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = { 'a', 'old', 'c' },
          current_lines = { 'a', 'new', 'c' },
          diff = diff,
        },
      }

      local lines, _, _, _, line_numbers = PatchLineBuilder.build(entries)

      eq(#lines, #line_numbers)
    end)

    it('should produce ascending marks across multiple files', function()
      local hunk1 = make_hunk('@@ -0,0 +1,1 @@', { '+new' })
      local diff1 = Diff():generate_unified({ hunk1 }, { 'new' })

      local hunk2 = make_hunk('@@ -1,1 +1,1 @@', { '-old', '+changed' })
      local diff2 = Diff():generate_unified({ hunk2 }, { 'changed' })

      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'a.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = { 'new' },
          diff = diff1,
        },
        {
          type = 'diff_file',
          filename = 'b.lua',
          filetype = 'lua',
          original_lines = { 'old' },
          current_lines = { 'changed' },
          diff = diff2,
        },
      }

      local lines, _, _, marks = PatchLineBuilder.build(entries)

      assert.is_true(#marks >= 2, 'should produce marks for each file')
      invariants.assert_patch_marks(marks, #lines)
    end)

    it('should set void lnum_change type in line_metadata for void lines', function()
      local component = create_patch_preview({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'test.lua',
          filetype = 'lua',
          original_lines = { 'a', 'removed' },
          current_lines = { 'a' },
          diff = {
            lines = { 'a', 'removed', 'a' },
            marks = { { top = 2, bot = 2 } },
            lnum_changes = {
              { lnum = 2, type = 'remove' },
            },
          },
        },
      }

      local _, line_metadata = PatchLineBuilder.build(entries)

      -- Check that remove type is preserved
      local found_remove = false
      for _, meta in pairs(line_metadata) do
        if meta.lnum_change and meta.lnum_change.type == 'remove' then found_remove = true end
      end
      assert.is_true(found_remove, 'should have remove lnum_change in line_metadata')
    end)
  end)

  describe('navigation cycle through marks', function()
    it('should visit all marks exactly once per cycle with hunk_down', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 8 },
            { top = 15, bot = 18 },
            { top = 25, bot = 28 },
          },
        },
      })
      component:set_lnum(1)

      local visited = {}
      for _ = 1, 4 do
        local mark = component:hunk_down()
        assert.is_truthy(mark)
        visited[#visited + 1] = mark.top
      end

      -- Should visit mark 1, 2, 3, then wrap to 1
      eq(5, visited[1])
      eq(15, visited[2])
      eq(25, visited[3])
      eq(5, visited[4])
    end)

    it('should visit all marks in reverse with hunk_up', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 8 },
            { top = 15, bot = 18 },
            { top = 25, bot = 28 },
          },
        },
      })
      component:set_lnum(30)

      local visited = {}
      for _ = 1, 4 do
        local mark = component:hunk_up()
        assert.is_truthy(mark)
        visited[#visited + 1] = mark.top
      end

      -- Should visit mark 3, 2, 1, then wrap to 3
      eq(25, visited[1])
      eq(15, visited[2])
      eq(5, visited[3])
      eq(25, visited[4])
    end)

    it('should not loop with a single mark', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 10, bot = 12 },
          },
        },
      })
      component:set_lnum(1)

      local mark1 = component:hunk_down()
      eq(10, mark1.top)

      local mark2 = component:hunk_down()
      eq(10, mark2.top)

      local mark3 = component:hunk_down()
      eq(10, mark3.top)
    end)

    it('should alternate between two marks without getting stuck', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 7 },
            { top = 20, bot = 22 },
          },
        },
      })
      component:set_lnum(1)

      local visited = {}
      for _ = 1, 6 do
        local mark = component:hunk_down()
        visited[#visited + 1] = mark.top
      end

      eq(5, visited[1])
      eq(20, visited[2])
      eq(5, visited[3])
      eq(20, visited[4])
      eq(5, visited[5])
      eq(20, visited[6])
    end)

    it('should navigate correctly from a gap between marks', function()
      local component = create_mounted_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 8 },
            { top = 15, bot = 18 },
            { top = 25, bot = 28 },
          },
        },
      })

      -- Start in gap between mark 1 and 2
      component:set_lnum(12)
      local mark = component:hunk_down()
      eq(15, mark.top)

      -- Start in gap between mark 2 and 3, go prev
      component:set_lnum(22)
      mark = component:hunk_up()
      eq(15, mark.top)
    end)
  end)
end)
