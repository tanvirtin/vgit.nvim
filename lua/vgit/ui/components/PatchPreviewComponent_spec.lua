local PatchHighlighter = require('vgit.ui.highlighters.PatchHighlighter')

local eq = assert.are.same

-- We test the pure logic methods of PatchPreviewComponent by constructing
-- a minimal object with just the fields those methods need, avoiding
-- the full Component lifecycle (which requires Neovim UI).
local function create_patch_preview(overrides)
  local PatchPreviewComponent = require('vgit.ui.components.PatchPreviewComponent')

  -- Create a minimal instance that bypasses Element creation
  local instance = {
    props = overrides.props or {},
    state = overrides.state or { lines = {}, line_metadata = {}, marks = {} },
    mounted = false,
    _needs_update = false,
    _viewport_dirty = true,
    _last_top = nil,
    _last_bot = nil,
    _renderer_attached = false,
    _element = nil,
    _patch_highlighter = PatchHighlighter(),
    _render_gen = 0,
  }

  setmetatable(instance, PatchPreviewComponent)
  return instance
end

describe('PatchPreviewComponent:', function()
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

      local lines, line_metadata, file_sections, marks = component:build_patch_lines_from_entries(entries)

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

      local lines, line_metadata, file_sections, marks = component:build_patch_lines_from_entries(entries)

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

      local lines, line_metadata, file_sections, marks = component:build_patch_lines_from_entries(entries)

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

      local lines, line_metadata = component:build_patch_lines_from_entries(entries)

      -- Find the diff content lines
      local found_code = false
      for i, meta in pairs(line_metadata) do
        if meta.type == 'code' and meta.filetype == 'lua' then
          found_code = true
        end
      end
      assert.is_true(found_code)
    end)

    it('should handle empty entries', function()
      local component = create_patch_preview({})
      local lines, line_metadata, file_sections, marks = component:build_patch_lines_from_entries({})

      eq(0, #lines)
      eq(0, #marks)
    end)

    it('should handle nil entries', function()
      local component = create_patch_preview({})
      local lines, line_metadata, file_sections, marks = component:build_patch_lines_from_entries(nil)

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

      local lines = component:build_patch_lines_from_entries(entries)

      -- Last line should not be empty (trailing blank removed)
      assert.are_not.equal('', lines[#lines])
    end)
  end)

  describe('build_patch_lines', function()
    it('should build all hunks when no selected index', function()
      local component = create_patch_preview({})
      local hunks = {
        {
          header = '@@ -1,2 +1,2 @@',
          diff = { ' line1', '-old', '+new' },
        },
        {
          header = '@@ -10,1 +10,1 @@',
          diff = { '-a', '+b' },
        },
      }

      local patch_lines = component:build_patch_lines(hunks, nil)

      -- Should include both hunks
      assert.is_true(#patch_lines > 0)
      local found_first_header = false
      local found_second_header = false
      for _, line in ipairs(patch_lines) do
        if line:match('@@ %-1') then found_first_header = true end
        if line:match('@@ %-10') then found_second_header = true end
      end
      assert.is_true(found_first_header)
      assert.is_true(found_second_header)
    end)

    it('should build only selected hunk', function()
      local component = create_patch_preview({})
      local hunks = {
        {
          header = '@@ -1,2 +1,2 @@',
          diff = { ' line1', '-old', '+new' },
        },
        {
          header = '@@ -10,1 +10,1 @@',
          diff = { '-a', '+b' },
        },
      }

      local patch_lines = component:build_patch_lines(hunks, 2)

      -- Should only include second hunk
      local found_first_header = false
      local found_second_header = false
      for _, line in ipairs(patch_lines) do
        if line:match('@@ %-1,2') then found_first_header = true end
        if line:match('@@ %-10') then found_second_header = true end
      end
      assert.is_false(found_first_header)
      assert.is_true(found_second_header)
    end)

    it('should handle empty hunks', function()
      local component = create_patch_preview({})
      local patch_lines = component:build_patch_lines({}, nil)
      eq(0, #patch_lines)
    end)

    it('should handle nil hunks', function()
      local component = create_patch_preview({})
      local patch_lines = component:build_patch_lines(nil, nil)
      eq(0, #patch_lines)
    end)

    it('should strip trailing empty line from multi-hunk output', function()
      local component = create_patch_preview({})
      local hunks = {
        { header = '@@ -1,1 +1,1 @@', diff = { '-a' } },
        { header = '@@ -5,1 +5,1 @@', diff = { '-b' } },
      }

      local patch_lines = component:build_patch_lines(hunks, nil)
      assert.are_not.equal('', patch_lines[#patch_lines])
    end)
  end)

  describe('calculate_line_numbers', function()
    it('should calculate line numbers for unified diff', function()
      local component = create_patch_preview({})
      local lines = {
        '────────────────',
        'test.lua',
        '────────────────',
        '@@ -1,3 +1,4 @@',
        'context',
        'removed',
        'added',
        'new_added',
      }
      local line_metadata = {
        [1] = { type = 'separator' },
        [2] = { type = 'filename' },
        [3] = { type = 'separator' },
        [4] = { type = 'code', is_header = true, hunk_header = '@@ -1,3 +1,4 @@' },
        [5] = { type = 'code' }, -- context
        [6] = { type = 'code', lnum_change = { type = 'remove' } },
        [7] = { type = 'code', lnum_change = { type = 'add' } },
        [8] = { type = 'code', lnum_change = { type = 'add' } },
      }

      local line_numbers = component:calculate_line_numbers(lines, line_metadata)

      eq(8, #line_numbers)

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

    it('should handle empty lines', function()
      local component = create_patch_preview({})
      local line_numbers = component:calculate_line_numbers({}, {})
      eq(0, #line_numbers)
    end)

    it('should reset counters at each hunk header', function()
      local component = create_patch_preview({})
      local lines = {
        '@@ -10,1 +20,1 @@',
        'context',
      }
      local line_metadata = {
        [1] = { type = 'code', is_header = true, hunk_header = '@@ -10,1 +20,1 @@' },
        [2] = { type = 'code' }, -- context
      }

      local line_numbers = component:calculate_line_numbers(lines, line_metadata)

      -- Context line should show line 20 (current start from hunk header)
      assert.is_truthy(line_numbers[2].text:match('20'))
    end)

    it('should handle blank metadata type', function()
      local component = create_patch_preview({})
      local lines = { '' }
      local line_metadata = {
        [1] = { type = 'blank' },
      }

      local line_numbers = component:calculate_line_numbers(lines, line_metadata)
      eq(1, #line_numbers)
      eq('GitLineNr', line_numbers[1].hl)
    end)
  end)

  describe('find_adjacent_mark_index', function()
    it('should find next mark when cursor is before first mark', function()
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      -- Mock get_lnum to return cursor at line 1
      component.get_lnum = function() return 1 end

      local idx = component:find_adjacent_mark_index('next')
      eq(1, idx)
    end)

    it('should find next mark when cursor is inside a mark', function()
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component.get_lnum = function() return 7 end

      local idx = component:find_adjacent_mark_index('next')
      eq(2, idx) -- next after current mark (index 1)
    end)

    it('should wrap to 1 when at last mark going next', function()
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component.get_lnum = function() return 25 end

      local idx = component:find_adjacent_mark_index('next')
      eq(1, idx) -- wraps to first
    end)

    it('should find previous mark when cursor is after last mark', function()
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component.get_lnum = function() return 25 end

      local idx = component:find_adjacent_mark_index('prev')
      eq(2, idx) -- last mark
    end)

    it('should find previous mark when cursor is inside a mark', function()
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component.get_lnum = function() return 17 end

      local idx = component:find_adjacent_mark_index('prev')
      eq(1, idx) -- previous mark (index 2 - 1)
    end)

    it('should wrap to last mark when before first mark going prev', function()
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
        },
      })
      component.get_lnum = function() return 1 end

      local idx = component:find_adjacent_mark_index('prev')
      eq(2, idx) -- wraps to last
    end)

    it('should return nil for empty marks', function()
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
        },
      })
      component.get_lnum = function() return 1 end

      local idx = component:find_adjacent_mark_index('next')
      eq(nil, idx)
    end)

    it('should find next mark when cursor is between marks', function()
      local component = create_patch_preview({
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
      component.get_lnum = function() return 12 end

      local idx = component:find_adjacent_mark_index('next')
      eq(2, idx) -- next mark after gap
    end)

    it('should find prev mark when cursor is between marks', function()
      local component = create_patch_preview({
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
      component.get_lnum = function() return 22 end

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

  describe('_render_viewport', function()
    it('should render line numbers and highlights for visible range', function()
      local lnum_calls = {}
      local hl_calls = {}
      local component = create_patch_preview({
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

      component._element = {
        is_valid = function() return true end,
        place_extmark_lnum = function(_, opts)
          lnum_calls[#lnum_calls + 1] = opts
        end,
        place_extmark_highlight = function(_, opts)
          hl_calls[#hl_calls + 1] = opts
        end,
        clear_extmark_highlights = function() end,
      }

      -- Render rows 0-1 (visible viewport)
      component:_render_viewport(0, 1)

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
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {},
          _syntax_hl_map = {},
          _line_numbers = {},
        },
      })

      component._element = {
        is_valid = function() return true end,
        place_extmark_lnum = function() end,
        place_extmark_highlight = function() end,
        clear_extmark_highlights = function() end,
      }

      -- Should not error
      component:_render_viewport(0, 10)
    end)
  end)

  describe('viewport dirty tracking', function()
    it('should skip _render_viewport when viewport is unchanged', function()
      local hl_calls = {}
      local component = create_patch_preview({
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

      component._element = {
        is_valid = function() return true end,
        place_extmark_lnum = function() end,
        place_extmark_highlight = function(_, opts)
          hl_calls[#hl_calls + 1] = opts
        end,
        clear_extmark_highlights = function() end,
      }

      -- First call should render
      component:_render_viewport(0, 0)
      local first_count = #hl_calls

      -- Second call with same range should skip
      component:_render_viewport(0, 0)
      eq(first_count, #hl_calls)
    end)

    it('should re-render when viewport range changes', function()
      local hl_calls = {}
      local component = create_patch_preview({
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

      component._element = {
        is_valid = function() return true end,
        place_extmark_lnum = function() end,
        place_extmark_highlight = function(_, opts)
          hl_calls[#hl_calls + 1] = opts
        end,
        clear_extmark_highlights = function() end,
      }

      component:_render_viewport(0, 0)
      local first_count = #hl_calls

      -- Different range should render
      component:_render_viewport(0, 1)
      assert.is_true(#hl_calls > first_count)
    end)

    it('should re-render after _viewport_dirty is set', function()
      local hl_calls = {}
      local component = create_patch_preview({
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

      component._element = {
        is_valid = function() return true end,
        place_extmark_lnum = function() end,
        place_extmark_highlight = function(_, opts)
          hl_calls[#hl_calls + 1] = opts
        end,
        clear_extmark_highlights = function() end,
      }

      component:_render_viewport(0, 0)
      local first_count = #hl_calls

      -- Mark dirty, same range should re-render
      component._viewport_dirty = true
      component:_render_viewport(0, 0)
      assert.is_true(#hl_calls > first_count)
    end)

    it('should clear highlights before re-rendering viewport', function()
      local clear_called = 0
      local component = create_patch_preview({
        state = {
          lines = {},
          line_metadata = {},
          marks = {},
          _diff_hl_map = {},
          _syntax_hl_map = {},
          _line_numbers = {},
        },
      })

      component._element = {
        is_valid = function() return true end,
        place_extmark_lnum = function() end,
        place_extmark_highlight = function() end,
        clear_extmark_highlights = function()
          clear_called = clear_called + 1
        end,
      }

      component:_render_viewport(0, 5)
      eq(1, clear_called)

      -- Change range to trigger re-render
      component:_render_viewport(0, 10)
      eq(2, clear_called)
    end)
  end)

  describe('should_component_update', function()
    it('should return true when patch_entries change', function()
      local component = create_patch_preview({
        props = { patch_entries = { 'a' }, hunks = nil, filetype = 'lua' },
      })

      local result = component:should_component_update({
        patch_entries = { 'b' },
        hunks = nil,
        filetype = 'lua',
      }, {})
      assert.is_true(result)
    end)

    it('should return true when hunks change', function()
      local component = create_patch_preview({
        props = { patch_entries = nil, hunks = { 'a' }, filetype = 'lua' },
      })

      local result = component:should_component_update({
        patch_entries = nil,
        hunks = { 'b' },
        filetype = 'lua',
      }, {})
      assert.is_true(result)
    end)

    it('should return true when filetype changes', function()
      local component = create_patch_preview({
        props = { patch_entries = nil, hunks = nil, filetype = 'lua' },
      })

      local result = component:should_component_update({
        patch_entries = nil,
        hunks = nil,
        filetype = 'python',
      }, {})
      assert.is_true(result)
    end)

    it('should return false when nothing changes', function()
      local entries = { 'same' }
      local hunks = { 'same' }
      local component = create_patch_preview({
        props = { patch_entries = entries, hunks = hunks, filetype = 'lua' },
      })

      local result = component:should_component_update({
        patch_entries = entries,
        hunks = hunks,
        filetype = 'lua',
      }, {})
      assert.is_false(result)
    end)
  end)

  describe('forward', function()
    it('should delegate place_extmark_highlight to element when valid', function()
      local called_with = nil
      local component = create_patch_preview({})
      component._element = {
        is_valid = function() return true end,
        place_extmark_highlight = function(_, opts)
          called_with = opts
          return 99
        end,
      }

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
      local component = create_patch_preview({})
      component._element = {
        is_valid = function() return true end,
      }
      assert.is_truthy(component:is_valid())
    end)

    it('should return self for chaining on void methods', function()
      local component = create_patch_preview({})
      eq(component, component:set_cursor({ 1, 0 }))
      eq(component, component:enable_cursorline())
      eq(component, component:disable_cursorline())
    end)
  end)

end)
