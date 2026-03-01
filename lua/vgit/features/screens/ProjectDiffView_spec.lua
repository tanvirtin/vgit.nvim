local eq = assert.are.same

describe('ProjectDiffView:', function()
  local ProjectDiffView

  before_each(function()
    ProjectDiffView = require('vgit.features.screens.ProjectDiffView')
  end)

  describe('_build_split_hunk_entries', function()
    it('should split file_header entries identically to both sides', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
        },
      }

      local prev, curr = view:_build_split_hunk_entries(entries)

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

      local prev, curr = view:_build_split_hunk_entries(entries)

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

      local prev, curr = view:_build_split_hunk_entries(entries)

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

      local prev, curr = view:_build_split_hunk_entries(entries)

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

      local prev, curr = view:_build_split_hunk_entries(entries)

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

      local prev, curr = view:_build_split_hunk_entries(entries)

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

      local prev, curr = view:_build_split_hunk_entries(entries)

      eq(0, #prev[1].hunk.diff)
      eq(0, #curr[1].hunk.diff)
    end)

    it('should handle empty entries', function()
      local view = ProjectDiffView()
      local prev, curr = view:_build_split_hunk_entries({})

      eq(0, #prev)
      eq(0, #curr)
    end)

    it('should void current-only conflict lines on previous pane and vice versa', function()
      local view = ProjectDiffView()
      -- Simulates a 5-line conflict: <<<, HEAD content, ===, incoming content, >>>
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,5 +1,5 @@ conflict',
            diff = {
              ' <<<<<<< HEAD',
              ' head content',
              ' =======',
              ' incoming content',
              ' >>>>>>> branch',
            },
            lnum_changes = {
              { type = 'conflict_current_mark' },
              { type = 'conflict_current' },
              { type = 'conflict_middle' },
              { type = 'conflict_incoming' },
              { type = 'conflict_incoming_mark' },
            },
            top = 1,
            bot = 5,
          },
          filetype = 'lua',
          filename = 'conflict.lua',
        },
      }

      local prev, curr = view:_build_split_hunk_entries(entries)

      -- Previous pane: current-only lines voided, incoming lines visible
      eq(' ', prev[1].hunk.diff[1]) -- <<<<<<< voided
      eq(' ', prev[1].hunk.diff[2]) -- HEAD content voided
      eq(' =======', prev[1].hunk.diff[3]) -- middle visible on both
      eq(' incoming content', prev[1].hunk.diff[4]) -- incoming visible
      eq(' >>>>>>> branch', prev[1].hunk.diff[5]) -- incoming mark visible
      eq('void', prev[1].hunk.lnum_changes[1].type)
      eq('void', prev[1].hunk.lnum_changes[2].type)
      eq('conflict_middle', prev[1].hunk.lnum_changes[3].type)
      eq('conflict_incoming', prev[1].hunk.lnum_changes[4].type)
      eq('conflict_incoming_mark', prev[1].hunk.lnum_changes[5].type)

      -- Current pane: incoming-only lines voided, current lines visible
      eq(' <<<<<<< HEAD', curr[1].hunk.diff[1]) -- current mark visible
      eq(' head content', curr[1].hunk.diff[2]) -- HEAD content visible
      eq(' =======', curr[1].hunk.diff[3]) -- middle visible on both
      eq(' ', curr[1].hunk.diff[4]) -- incoming voided
      eq(' ', curr[1].hunk.diff[5]) -- incoming mark voided
      eq('conflict_current_mark', curr[1].hunk.lnum_changes[1].type)
      eq('conflict_current', curr[1].hunk.lnum_changes[2].type)
      eq('conflict_middle', curr[1].hunk.lnum_changes[3].type)
      eq('void', curr[1].hunk.lnum_changes[4].type)
      eq('void', curr[1].hunk.lnum_changes[5].type)
    end)
  end)

  describe('_build_hunk_entries', function()
    local mock_repo

    before_each(function()
      mock_repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
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

      local hunk_entries, line_to_file_map = view:_build_hunk_entries(mock_repo, data)

      assert.is_true(#hunk_entries > 0)
      eq('file_header', hunk_entries[1].type)
      eq('a.lua', hunk_entries[1].filename)
      eq('hunk', hunk_entries[2].type)
      eq('a.lua', hunk_entries[2].filename)
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

      local hunk_entries = view:_build_hunk_entries(mock_repo, data)
      eq(0, #hunk_entries)
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

      local hunk_entries = view:_build_hunk_entries(mock_repo, data)
      eq(0, #hunk_entries)
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

      local hunk_entries = view:_build_hunk_entries(mock_repo, data)
      eq(0, #hunk_entries)
    end)

    it('should handle empty data entries', function()
      local view = ProjectDiffView()
      local data = { entries = {} }

      local hunk_entries, line_to_file_map = view:_build_hunk_entries(mock_repo, data)
      eq(0, #hunk_entries)
      eq(0, vim.tbl_count(line_to_file_map))
    end)

    it('should handle nil data entries', function()
      local view = ProjectDiffView()
      local data = {}

      local hunk_entries, line_to_file_map = view:_build_hunk_entries(mock_repo, data)
      eq(0, #hunk_entries)
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

      local hunk_entries, line_to_file_map = view:_build_hunk_entries(mock_repo, data)

      -- Should have entries for both files
      assert.is_true(#hunk_entries >= 4) -- 2 file_headers + 2 hunks

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

      local hunk_entries = view:_build_hunk_entries(mock_repo, data)

      eq('file_header', hunk_entries[1].type)
      eq(orig, hunk_entries[1].original_lines)
      eq(curr, hunk_entries[1].current_lines)
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

      local hunk_entries = view:_build_hunk_entries(mock_repo, data)

      eq('file_header', hunk_entries[1].type)
      eq('old_name.lua -> new_name.lua', hunk_entries[1].filename)
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

      local _, line_to_file_map = view:_build_hunk_entries(mock_repo, data)

      -- All mapped lines should reference a.lua
      for _, info in pairs(line_to_file_map) do
        eq('a.lua', info.filename)
      end

      -- Should have line mappings (3 header lines + hunk header + 2 diff lines + separator + hunk header + 2 diff lines + separator)
      local count = vim.tbl_count(line_to_file_map)
      assert.is_true(count > 0)
    end)
  end)

  describe('_build_hunk_entries with status entries (mocked repo:diff)', function()
    -- event.all uses coroutine.yield so tests must run in an async context
    local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
    local it = async.it

    local function mock_repo(diff_fn)
      return {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = diff_fn or function()
          return {}
        end,
      }
    end

    it('should call repo:diff for staged entry without pre-computed diff', function()
      local staged_called = false
      local repo = mock_repo(function(_, spec)
        if spec.from == 'HEAD' and spec.to == 'index' then
          staged_called = true
          return {
            { type = 'file_header', filename = 'staged.lua', filetype = 'lua' },
            {
              type = 'hunk',
              hunk = { header = '@@ -1,1 +1,1 @@', diff = { '-old', '+new' }, top = 1, bot = 1 },
              filetype = 'lua',
              filename = 'staged.lua',
            },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                type = 'staged',
                status = { filename = 'staged.lua', filetype = 'lua' },
                -- no diff field — should use batch fetch
              },
            },
          },
        },
      }

      local hunk_entries = view:_build_hunk_entries(repo, data)

      assert.is_true(staged_called)
      eq(2, #hunk_entries)
      eq('file_header', hunk_entries[1].type)
      eq('staged.lua', hunk_entries[1].filename)
      eq('hunk', hunk_entries[2].type)
    end)

    it('should call repo:diff for unstaged entry without pre-computed diff', function()
      local unstaged_called = false
      local repo = mock_repo(function(_, spec)
        if spec.to == 'disk' then
          unstaged_called = true
          return {
            { type = 'file_header', filename = 'unstaged.lua', filetype = 'lua' },
            {
              type = 'hunk',
              hunk = { header = '@@ -2,1 +2,1 @@', diff = { '-x', '+y' }, top = 2, bot = 2 },
              filetype = 'lua',
              filename = 'unstaged.lua',
            },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                type = 'unstaged',
                status = { filename = 'unstaged.lua', filetype = 'lua' },
              },
            },
          },
        },
      }

      local hunk_entries = view:_build_hunk_entries(repo, data)

      assert.is_true(unstaged_called)
      eq(2, #hunk_entries)
      eq('file_header', hunk_entries[1].type)
      eq('unstaged.lua', hunk_entries[1].filename)
    end)

    it('should call repo:diff for both staged and unstaged when both types are present', function()
      local staged_called = false
      local unstaged_called = false

      local repo = mock_repo(function(_, spec)
        if spec.from == 'HEAD' and spec.to == 'index' then
          staged_called = true
          return {
            { type = 'file_header', filename = 'staged.lua', filetype = 'lua' },
            {
              type = 'hunk',
              hunk = { header = '@@ -1,1 +1,1 @@', diff = { '-a', '+b' }, top = 1, bot = 1 },
              filetype = 'lua',
              filename = 'staged.lua',
            },
          }
        elseif spec.to == 'disk' then
          unstaged_called = true
          return {
            { type = 'file_header', filename = 'unstaged.lua', filetype = 'lua' },
            {
              type = 'hunk',
              hunk = { header = '@@ -3,1 +3,1 @@', diff = { '-c', '+d' }, top = 3, bot = 3 },
              filetype = 'lua',
              filename = 'unstaged.lua',
            },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              { type = 'staged', status = { filename = 'staged.lua', filetype = 'lua' } },
              { type = 'unstaged', status = { filename = 'unstaged.lua', filetype = 'lua' } },
            },
          },
        },
      }

      local hunk_entries = view:_build_hunk_entries(repo, data)

      assert.is_true(staged_called)
      assert.is_true(unstaged_called)
      -- 2 file_headers + 2 hunks = 4 entries total
      eq(4, #hunk_entries)
    end)

    it('should return empty hunk_entries when repo:diff returns error (nil)', function()
      local repo = mock_repo(function()
        return nil, { 'git error' }
      end)

      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              { type = 'staged', status = { filename = 'staged.lua', filetype = 'lua' } },
            },
          },
        },
      }

      -- Should not crash; returns empty (nil result → no entries added)
      local hunk_entries = view:_build_hunk_entries(repo, data)
      eq(0, #hunk_entries)
    end)

    it('should build correct line_to_file_map with top from hunk header', function()
      local repo = mock_repo(function(_, spec)
        if spec.to == 'disk' then
          return {
            { type = 'file_header', filename = 'foo.lua', filetype = 'lua' },
            {
              type = 'hunk',
              hunk = { header = '@@ -10,2 +10,2 @@', diff = { '-x', '+y' }, top = 10, bot = 11 },
              filetype = 'lua',
              filename = 'foo.lua',
            },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              { type = 'unstaged', status = { filename = 'foo.lua', filetype = 'lua' } },
            },
          },
        },
      }

      local _, line_to_file_map = view:_build_hunk_entries(repo, data)

      -- 3 file_header lines + 1 hunk_header line + 2 diff lines + 1 separator = 7 entries
      -- The hunk header line should map to lnum=10 (hunk.top)
      -- Line 4 is the hunk header line (after 3 file_header lines)
      eq(10, line_to_file_map[4].lnum)
      eq('foo.lua', line_to_file_map[4].filename)
    end)

    it('should not call repo:diff for pre-computed entries', function()
      local diff_called = false

      local repo = mock_repo(function()
        diff_called = true
        return {}
      end)

      local view = ProjectDiffView()
      local data = {
        entries = {
          {
            entries = {
              {
                -- Pre-computed diff — should NOT trigger batch fetch
                status = { filename = 'pre.lua', filetype = 'lua' },
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

      local hunk_entries = view:_build_hunk_entries(repo, data)

      assert.is_false(diff_called)
      -- Pre-computed entry is still included
      eq(2, #hunk_entries)
      eq('pre.lua', hunk_entries[1].filename)
    end)
  end)

  describe('_build_hunk_entries with conflict entries', function()
    -- event.all uses coroutine.yield so tests must run in an async context
    local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
    local it = async.it

    it('should include conflict entry when DiffBuilder returns valid diff_data', function()
      local view = ProjectDiffView()

      -- Conflict diffs return marks+lnum_changes (hunks is always {})
      view._get_diff_for_entry = function(self, repo, entry)
        return {
          hunks = {},
          marks = {
            {
              type = 'conflict',
              top = 1,
              bot = 5,
              top_relative = 1,
              bot_relative = 5,
            },
          },
          lines = {
            '<<<<<<< HEAD',
            'old content',
            '=======',
            'new content',
            '>>>>>>> branch',
          },
          lnum_changes = {
            { lnum = 1, buftype = 'current', type = 'conflict_current_mark' },
            { lnum = 2, buftype = 'current', type = 'conflict_current' },
            { lnum = 3, buftype = 'current', type = 'conflict_middle' },
            { lnum = 4, buftype = 'current', type = 'conflict_incoming' },
            { lnum = 5, buftype = 'current', type = 'conflict_incoming_mark' },
          },
        }
      end

      local data = {
        entries = {
          {
            entries = {
              {
                type = 'unmerged',
                status = { filename = 'conflict.lua', filetype = 'lua' },
              },
            },
          },
        },
      }

      local repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local hunk_entries = view:_build_hunk_entries(repo, data)

      -- Should have file_header + hunk for the conflict file
      assert.is_true(#hunk_entries >= 2)
      eq('file_header', hunk_entries[1].type)
      eq('conflict.lua', hunk_entries[1].filename)
      eq('hunk', hunk_entries[2].type)
      -- Conflict region lines rendered as context (space prefix preserves actual content)
      eq(5, #hunk_entries[2].hunk.diff)
      eq(' <<<<<<< HEAD', hunk_entries[2].hunk.diff[1])
      eq(' >>>>>>> branch', hunk_entries[2].hunk.diff[5])
      eq(1, hunk_entries[2].hunk.top)
      eq(5, hunk_entries[2].hunk.bot)
      -- lnum_changes carries conflict-specific highlight types
      eq('conflict_current_mark', hunk_entries[2].hunk.lnum_changes[1].type)
      eq('conflict_current', hunk_entries[2].hunk.lnum_changes[2].type)
      eq('conflict_middle', hunk_entries[2].hunk.lnum_changes[3].type)
      eq('conflict_incoming', hunk_entries[2].hunk.lnum_changes[4].type)
      eq('conflict_incoming_mark', hunk_entries[2].hunk.lnum_changes[5].type)
    end)

    it('should exclude conflict entry when DiffBuilder returns nil (error)', function()
      local view = ProjectDiffView()

      view._get_diff_for_entry = function(self, repo, entry)
        return nil
      end

      local data = {
        entries = {
          {
            entries = {
              {
                type = 'unmerged',
                status = { filename = 'conflict.lua', filetype = 'lua' },
              },
            },
          },
        },
      }

      local repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local hunk_entries = view:_build_hunk_entries(repo, data)

      -- No entries because conflict DiffBuilder returned nil
      eq(0, #hunk_entries)
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

  describe('destroy', function()
    it('should be idempotent (safe to call multiple times)', function()
      local view = ProjectDiffView()
      view._component_manager = { destroy = function() end }
      view._patch_component = { component_will_unmount = function() end }

      view:destroy()
      view:destroy() -- second call should not error
      assert.is_true(view._destroyed)
    end)

    it('should set _destroyed to true', function()
      local view = ProjectDiffView()
      view._component_manager = { destroy = function() end }

      assert.is_false(view._destroyed)
      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should increment _update_gen to invalidate background enrichment', function()
      local view = ProjectDiffView()
      view._component_manager = { destroy = function() end }

      local gen_before = view._update_gen
      view:destroy()
      assert.is_true(view._update_gen > gen_before)
    end)

    it('should call each debounce cleanup function', function()
      local cleanup1_calls = 0
      local cleanup2_calls = 0
      local view = ProjectDiffView()
      view._debounce_cleanups = {
        function()
          cleanup1_calls = cleanup1_calls + 1
        end,
        function()
          cleanup2_calls = cleanup2_calls + 1
        end,
      }
      view._component_manager = { destroy = function() end }

      view:destroy()
      eq(1, cleanup1_calls)
      eq(1, cleanup2_calls)
      -- Second call is a no-op (idempotent)
      view:destroy()
      eq(1, cleanup1_calls)
      eq(1, cleanup2_calls)
    end)
  end)

  describe('_enrich_with_syntax', function()
    it('should exit early when view is destroyed', function()
      local view = ProjectDiffView()
      view._destroyed = true
      view._repo = {
        file_lines = function()
          error('should not be called')
        end,
      }
      -- Should not call file_lines or error
      view:_enrich_with_syntax(
        { { type = 'file_header', filename = 'foo.lua', filetype = 'lua' } },
        { entries = {} },
        1
      )
    end)

    it('should exit early when gen is stale', function()
      local view = ProjectDiffView()
      view._destroyed = false
      view._update_gen = 2 -- current gen is 2, but we pass gen=1
      view._repo = {
        file_lines = function()
          error('should not be called')
        end,
      }
      view:_enrich_with_syntax(
        { { type = 'file_header', filename = 'foo.lua', filetype = 'lua' } },
        { entries = {} },
        1
      )
    end)

    it('should exit early when repo is nil', function()
      local view = ProjectDiffView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = nil
      -- Should not error
      view:_enrich_with_syntax(
        { { type = 'file_header', filename = 'foo.lua', filetype = 'lua' } },
        { entries = {} },
        1
      )
    end)

    it('should exit early when all file_header entries have filetype text', function()
      local view = ProjectDiffView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local entries = {
        { type = 'file_header', filename = 'README', filetype = 'text' },
        { type = 'hunk', filename = 'README', filetype = 'text', hunk = {} },
      }
      -- Should not call file_lines, so no coroutine/event.all issues
      view:_enrich_with_syntax(entries, { entries = {} }, 1)
    end)

    it('should exit early when all file_headers already have original_lines (pre-computed)', function()
      local view = ProjectDiffView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local entries = {
        {
          type = 'file_header',
          filename = 'foo.lua',
          filetype = 'lua',
          original_lines = { 'old' },
          current_lines = { 'new' },
        },
      }
      -- Pre-computed entries are skipped — no file_lines calls needed
      view:_enrich_with_syntax(entries, { entries = {} }, 1)
    end)

    it('should exit early when there are no file_header entries', function()
      local view = ProjectDiffView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local entries = {
        { type = 'hunk', filename = 'foo.lua', filetype = 'lua', hunk = {} },
      }
      view:_enrich_with_syntax(entries, { entries = {} }, 1)
    end)

    it('should exit early when all non-text file_headers are conflicts (unmerged)', function()
      local view = ProjectDiffView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local data = {
        entries = {
          {
            entries = {
              { type = 'unmerged', status = { filename = 'conflict.lua' } },
            },
          },
        },
      }
      local hunk_entries = {
        { type = 'file_header', filename = 'conflict.lua', filetype = 'lua' },
      }
      -- Conflict entries are skipped in enrichment
      view:_enrich_with_syntax(hunk_entries, data, 1)
    end)
  end)
end)
