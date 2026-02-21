local eq = assert.are.same

describe('ProjectDiffView:', function()
  local ProjectDiffView

  before_each(function()
    ProjectDiffView = require('vgit.features.screens.ProjectDiffView')
  end)

  describe('_build_split_patch_entries', function()
    it('should split file_header entries identically to both sides', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(1, #prev)
      eq(1, #curr)
      eq('file_header', prev[1].type)
      eq('file_header', curr[1].type)
      eq('test.lua', prev[1].filename)
      eq('test.lua', curr[1].filename)
    end)

    it('should split hunk with added lines', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,1 +1,2 @@',
            diff = {
              ' context',
              '+added',
            },
            top = 1,
            bot = 2,
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(1, #prev)
      eq(1, #curr)

      -- Previous side: context + space placeholder for added line
      eq(2, #prev[1].hunk.diff)
      eq(' context', prev[1].hunk.diff[1])
      eq(' ', prev[1].hunk.diff[2]) -- placeholder

      -- Current side: context + added line
      eq(2, #curr[1].hunk.diff)
      eq(' context', curr[1].hunk.diff[1])
      eq('+added', curr[1].hunk.diff[2])
    end)

    it('should split hunk with removed lines', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,2 +1,1 @@',
            diff = {
              ' context',
              '-removed',
            },
            top = 1,
            bot = 2,
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      -- Previous side: context + removed line
      eq(' context', prev[1].hunk.diff[1])
      eq('-removed', prev[1].hunk.diff[2])

      -- Current side: context + space placeholder
      eq(' context', curr[1].hunk.diff[1])
      eq(' ', curr[1].hunk.diff[2]) -- placeholder
    end)

    it('should split hunk with mixed changes', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,3 +1,3 @@',
            diff = {
              ' context1',
              '-old_line',
              '+new_line',
              ' context2',
            },
            top = 1,
            bot = 4,
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(4, #prev[1].hunk.diff)
      eq(4, #curr[1].hunk.diff)

      -- Context lines identical
      eq(' context1', prev[1].hunk.diff[1])
      eq(' context1', curr[1].hunk.diff[1])
      eq(' context2', prev[1].hunk.diff[4])
      eq(' context2', curr[1].hunk.diff[4])

      -- Removed line: present in prev, space in curr
      eq('-old_line', prev[1].hunk.diff[2])
      eq(' ', curr[1].hunk.diff[2])

      -- Added line: space in prev, present in curr
      eq(' ', prev[1].hunk.diff[3])
      eq('+new_line', curr[1].hunk.diff[3])
    end)

    it('should preserve hunk metadata', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -5,2 +5,2 @@',
            diff = { '-a', '+b' },
            top = 5,
            bot = 6,
          },
          filetype = 'python',
          filename = 'app.py',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq('@@ -5,2 +5,2 @@', prev[1].hunk.header)
      eq('@@ -5,2 +5,2 @@', curr[1].hunk.header)
      eq(5, prev[1].hunk.top)
      eq(5, curr[1].hunk.top)
      eq(6, prev[1].hunk.bot)
      eq(6, curr[1].hunk.bot)
      eq('python', prev[1].filetype)
      eq('python', curr[1].filetype)
      eq('app.py', prev[1].filename)
      eq('app.py', curr[1].filename)
    end)

    it('should handle multiple files and hunks', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'file_header',
          filename = 'a.lua',
          filetype = 'lua',
        },
        {
          type = 'hunk',
          hunk = { header = '@@ -1,1 +1,1 @@', diff = { '-x', '+y' }, top = 1, bot = 1 },
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
          hunk = { header = '@@ -1,1 +1,1 @@', diff = { '-m', '+n' }, top = 1, bot = 1 },
          filetype = 'lua',
          filename = 'b.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(4, #prev)
      eq(4, #curr)
      eq('file_header', prev[1].type)
      eq('hunk', prev[2].type)
      eq('file_header', prev[3].type)
      eq('hunk', prev[4].type)
    end)

    it('should handle empty diff in hunk', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = { header = '@@ -1,0 +1,0 @@', diff = {} },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(0, #prev[1].hunk.diff)
      eq(0, #curr[1].hunk.diff)
    end)

    it('should handle empty entries', function()
      local view = ProjectDiffView()
      local prev, curr = view:_build_split_patch_entries({})

      eq(0, #prev)
      eq(0, #curr)
    end)
  end)

  describe('_build_patch_entries', function()
    local mock_repo

    before_each(function()
      mock_repo = {}
    end)

    it('should build patch entries from pre-computed diffs', function()
      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'a.lua', filetype = 'lua' },
                diff = {
                  hunks = {
                    { header = '@@ -1,1 +1,1 @@', diff = { '-old', '+new' }, top = 1, bot = 1 },
                  },
                },
                original_lines = { 'old' },
                current_lines = { 'new' },
              },
            },
          },
        },
      }

      local patch_entries, line_to_file_map = view:_build_patch_entries(mock_repo, data)

      assert.is_true(#patch_entries > 0)
      eq('file_header', patch_entries[1].type)
      eq('a.lua', patch_entries[1].filename)
      eq('hunk', patch_entries[2].type)
      eq('a.lua', patch_entries[2].filename)
      assert.is_not_nil(line_to_file_map[1])
      eq('a.lua', line_to_file_map[1].filename)
    end)

    it('should skip entries without status', function()
      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              { diff = { hunks = { { header = '@@', diff = { '+x' }, top = 1, bot = 1 } } } },
            },
          },
        },
      }

      local patch_entries = view:_build_patch_entries(mock_repo, data)
      eq(0, #patch_entries)
    end)

    it('should skip entries where diff has no hunks after population', function()
      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'a.lua' },
                diff = { hunks = nil },
              },
            },
          },
        },
      }

      local patch_entries = view:_build_patch_entries(mock_repo, data)
      eq(0, #patch_entries)
    end)

    it('should skip entries with empty hunks', function()
      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'a.lua' },
                diff = { hunks = {} },
              },
            },
          },
        },
      }

      local patch_entries = view:_build_patch_entries(mock_repo, data)
      eq(0, #patch_entries)
    end)

    it('should handle empty data entries', function()
      local view = ProjectDiffView()
      local data = { entries = {} }

      local patch_entries, line_to_file_map = view:_build_patch_entries(mock_repo, data)
      eq(0, #patch_entries)
      eq(0, vim.tbl_count(line_to_file_map))
    end)

    it('should handle nil data entries', function()
      local view = ProjectDiffView()
      local data = {}

      local patch_entries, line_to_file_map = view:_build_patch_entries(mock_repo, data)
      eq(0, #patch_entries)
      eq(0, vim.tbl_count(line_to_file_map))
    end)

    it('should build correct line_to_file_map for multi-file data', function()
      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'first.lua', filetype = 'lua' },
                diff = {
                  hunks = {
                    { header = '@@ -1,1 +1,1 @@', diff = { '-a', '+b' }, top = 1, bot = 1 },
                  },
                },
              },
              {
                status = { filename = 'second.lua', filetype = 'lua' },
                diff = {
                  hunks = {
                    { header = '@@ -1,1 +1,1 @@', diff = { '-x', '+y' }, top = 1, bot = 1 },
                  },
                },
              },
            },
          },
        },
      }

      local patch_entries, line_to_file_map = view:_build_patch_entries(mock_repo, data)

      -- Should have entries for both files
      assert.is_true(#patch_entries >= 4) -- 2 file_headers + 2 hunks

      -- line_to_file_map should reference both files
      local filenames_seen = {}
      for _, info in pairs(line_to_file_map) do
        filenames_seen[info.filename] = true
      end
      assert.is_true(filenames_seen['first.lua'] == true)
      assert.is_true(filenames_seen['second.lua'] == true)
    end)

    it('should include original_lines and current_lines in file_header entries', function()
      local view = ProjectDiffView()
      local orig = { 'old_line' }
      local curr = { 'new_line' }
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'a.lua', filetype = 'lua' },
                diff = {
                  hunks = {
                    { header = '@@ -1,1 +1,1 @@', diff = { '-old_line', '+new_line' }, top = 1, bot = 1 },
                  },
                },
                original_lines = orig,
                current_lines = curr,
              },
            },
          },
        },
      }

      local patch_entries = view:_build_patch_entries(mock_repo, data)

      eq('file_header', patch_entries[1].type)
      eq(orig, patch_entries[1].original_lines)
      eq(curr, patch_entries[1].current_lines)
    end)

    it('should display renamed files correctly', function()
      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'new_name.lua', old_filename = 'old_name.lua', filetype = 'lua' },
                diff = {
                  hunks = {
                    { header = '@@ -1,1 +1,1 @@', diff = { '-a', '+b' }, top = 1, bot = 1 },
                  },
                },
              },
            },
          },
        },
      }

      local patch_entries = view:_build_patch_entries(mock_repo, data)

      eq('file_header', patch_entries[1].type)
      eq('old_name.lua -> new_name.lua', patch_entries[1].filename)
    end)

    it('should track line numbers correctly across hunks', function()
      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'a.lua', filetype = 'lua' },
                diff = {
                  hunks = {
                    { header = '@@ -1,1 +1,1 @@', diff = { '-a', '+b' }, top = 1, bot = 1 },
                    { header = '@@ -5,1 +5,1 @@', diff = { '-x', '+y' }, top = 5, bot = 5 },
                  },
                },
              },
            },
          },
        },
      }

      local _, line_to_file_map = view:_build_patch_entries(mock_repo, data)

      -- All mapped lines should reference a.lua
      for _, info in pairs(line_to_file_map) do
        eq('a.lua', info.filename)
      end

      -- Should have line mappings (3 header lines + hunk header + 2 diff lines + separator + hunk header + 2 diff lines + separator)
      local count = vim.tbl_count(line_to_file_map)
      assert.is_true(count > 0)
    end)
  end)

  describe('_get_active_component', function()
    it('should return current_component for split layout', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_SPLIT
      view._current_component = 'current'
      view._patch_component = 'patch'

      eq('current', view:_get_active_component())
    end)

    it('should return patch_component for unified layout', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      view._current_component = 'current'
      view._patch_component = 'patch'

      eq('patch', view:_get_active_component())
    end)

    it('should return patch_component for nil layout', function()
      local view = ProjectDiffView()
      view._layout_type = nil
      view._patch_component = 'patch'

      eq('patch', view:_get_active_component())
    end)
  end)

end)
