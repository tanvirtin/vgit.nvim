local eq = assert.are.same

describe('ProjectDiffView:', function()
  local ProjectDiffView

  before_each(function()
    ProjectDiffView = require('vgit.features.screens.ProjectDiffView')
  end)

  describe('_build_line_to_file_map', function()
    it('should extract filename and file_lnum from component line_metadata', function()
      local view = ProjectDiffView()
      local metadata = {
        [1] = { type = 'separator' },
        [2] = { type = 'filename', filename = 'test.lua' },
        [3] = { type = 'separator' },
        [4] = { type = 'code', filetype = 'lua', filename = 'test.lua', file_lnum = 5 },
        [5] = { type = 'code', filetype = 'lua', filename = 'test.lua', file_lnum = 6 },
        [6] = { type = 'blank' },
      }
      local mock_component = {
        get_all_line_metadata = function()
          return metadata
        end,
      }

      local map = view:_build_line_to_file_map(mock_component)

      eq('test.lua', map[4].filename)
      eq(5, map[4].lnum)
      eq('test.lua', map[5].filename)
      eq(6, map[5].lnum)
      assert.is_nil(map[1])
      assert.is_nil(map[6])
    end)

    it('should handle multiple files in metadata', function()
      local view = ProjectDiffView()
      local metadata = {
        [1] = { type = 'code', filetype = 'lua', filename = 'a.lua', file_lnum = 1 },
        [2] = { type = 'code', filetype = 'lua', filename = 'a.lua', file_lnum = 2 },
        [3] = { type = 'code', filetype = 'lua', filename = 'b.lua', file_lnum = 10 },
      }
      local mock_component = {
        get_all_line_metadata = function()
          return metadata
        end,
      }

      local map = view:_build_line_to_file_map(mock_component)

      eq('a.lua', map[1].filename)
      eq(1, map[1].lnum)
      eq('b.lua', map[3].filename)
      eq(10, map[3].lnum)
    end)

    it('should return empty map for empty metadata', function()
      local view = ProjectDiffView()
      local mock_component = {
        get_all_line_metadata = function()
          return {}
        end,
      }

      local map = view:_build_line_to_file_map(mock_component)
      eq(0, vim.tbl_count(map))
    end)

    it('should default file_lnum to 1 when not set', function()
      local view = ProjectDiffView()
      local metadata = {
        [1] = { type = 'code', filename = 'test.lua' },
      }
      local mock_component = {
        get_all_line_metadata = function()
          return metadata
        end,
      }

      local map = view:_build_line_to_file_map(mock_component)
      eq(1, map[1].lnum)
    end)
  end)

  describe('_build_diff_file_entries with precomputed diffs', function()
    local mock_repo

    before_each(function()
      mock_repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {}
        end,
      }
    end)

    it('should build diff_file entries from precomputed diffs', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'a.lua', filetype = 'lua' },
                diff = {
                  lines = { 'line1' },
                  lnum_changes = {},
                  marks = {},
                  hunks = { {} },
                },
                original_lines = { 'old' },
                current_lines = { 'new' },
              },
            },
          },
        },
      }

      local entries = view:_build_diff_file_entries(mock_repo, data)

      eq(1, #entries)
      eq('diff_file', entries[1].type)
      eq('a.lua', entries[1].filename)
      eq('lua', entries[1].filetype)
      eq({ 'old' }, entries[1].original_lines)
      eq({ 'new' }, entries[1].current_lines)
    end)

    it('should skip entries without status', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = {
        entries = {
          {
            entries = {
              { diff = { lines = {}, lnum_changes = {}, marks = {}, hunks = { {} } } },
            },
          },
        },
      }

      local entries = view:_build_diff_file_entries(mock_repo, data)
      eq(0, #entries)
    end)

    it('should handle empty data entries', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = { entries = {} }

      local entries = view:_build_diff_file_entries(mock_repo, data)
      eq(0, #entries)
    end)

    it('should handle nil data entries', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = {}

      local entries = view:_build_diff_file_entries(mock_repo, data)
      eq(0, #entries)
    end)

    it('should display renamed files correctly', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'new_name.lua', old_filename = 'old_name.lua', filetype = 'lua' },
                diff = {
                  lines = { 'content' },
                  lnum_changes = {},
                  marks = {},
                  hunks = { {} },
                },
              },
            },
          },
        },
      }

      local entries = view:_build_diff_file_entries(mock_repo, data)

      eq(1, #entries)
      eq('diff_file', entries[1].type)
      eq('old_name.lua -> new_name.lua', entries[1].filename)
    end)

    it('should not call repo:diff for precomputed entries', function()
      local diff_called = false

      local repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          diff_called = true
          return {}
        end,
      }

      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'pre.lua', filetype = 'lua' },
                diff = {
                  lines = { 'content' },
                  lnum_changes = {},
                  marks = {},
                  hunks = { {} },
                },
              },
            },
          },
        },
      }

      local entries = view:_build_diff_file_entries(repo, data)

      assert.is_false(diff_called)
      eq(1, #entries)
      eq('pre.lua', entries[1].filename)
    end)
  end)

  describe('_build_diff_file_entries with status entries (mocked repo:diff)', function()
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

    it('should call repo:diff with layout_type for staged entries', function()
      local called_with_layout_type = nil
      local repo = mock_repo(function(_, spec)
        if spec.from == 'HEAD' and spec.to == 'index' then
          called_with_layout_type = spec.layout_type
          return {
            {
              filename = 'staged.lua',
              filetype = 'lua',
              diff = { lines = { 'content' }, lnum_changes = {}, marks = {} },
              original_lines = { 'old' },
              current_lines = { 'new' },
            },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = {
        entries = {
          {
            entries = {
              {
                type = 'staged',
                status = { filename = 'staged.lua', filetype = 'lua' },
              },
            },
          },
        },
      }

      local entries = view:_build_diff_file_entries(repo, data)

      eq('unified', called_with_layout_type)
      eq(1, #entries)
      eq('diff_file', entries[1].type)
      eq('staged.lua', entries[1].filename)
    end)

    it('should call repo:diff for unstaged entries', function()
      local unstaged_called = false
      local repo = mock_repo(function(_, spec)
        if spec.to == 'disk' then
          unstaged_called = true
          return {
            {
              filename = 'unstaged.lua',
              filetype = 'lua',
              diff = { lines = { 'content' }, lnum_changes = {}, marks = {} },
              original_lines = {},
              current_lines = { 'new' },
            },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
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

      local entries = view:_build_diff_file_entries(repo, data)

      assert.is_true(unstaged_called)
      eq(1, #entries)
      eq('diff_file', entries[1].type)
      eq('unstaged.lua', entries[1].filename)
    end)

    it('should call repo:diff for both staged and unstaged when both types are present', function()
      local staged_called = false
      local unstaged_called = false

      local repo = mock_repo(function(_, spec)
        if spec.from == 'HEAD' and spec.to == 'index' then
          staged_called = true
          return {
            {
              filename = 'staged.lua',
              filetype = 'lua',
              diff = { lines = { 'a' }, lnum_changes = {}, marks = {} },
              original_lines = {},
              current_lines = { 'a' },
            },
          }
        elseif spec.to == 'disk' then
          unstaged_called = true
          return {
            {
              filename = 'unstaged.lua',
              filetype = 'lua',
              diff = { lines = { 'b' }, lnum_changes = {}, marks = {} },
              original_lines = {},
              current_lines = { 'b' },
            },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
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

      local entries = view:_build_diff_file_entries(repo, data)

      assert.is_true(staged_called)
      assert.is_true(unstaged_called)
      eq(2, #entries)
    end)

    it('should return empty entries when repo:diff returns error', function()
      local repo = mock_repo(function()
        return nil, { 'git error' }
      end)

      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      local data = {
        entries = {
          {
            entries = {
              { type = 'staged', status = { filename = 'staged.lua', filetype = 'lua' } },
            },
          },
        },
      }

      local entries = view:_build_diff_file_entries(repo, data)
      eq(0, #entries)
    end)

    it('should handle conflict entries via repo:diff', function()
      local conflict_called = false
      local repo = mock_repo(function(_, spec)
        if spec.type == 'conflict' then
          conflict_called = true
          return {
            lines = { '<<<', 'ours', '===', 'theirs', '>>>' },
            lnum_changes = {
              { lnum = 1, type = 'conflict_current_mark' },
            },
            marks = { { top = 1, bot = 5 } },
          }
        end
        return {}
      end)

      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
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

      local entries = view:_build_diff_file_entries(repo, data)

      assert.is_true(conflict_called)
      eq(1, #entries)
      eq('diff_file', entries[1].type)
      eq('conflict.lua', entries[1].filename)
    end)
  end)

  describe('get_navigatable_component', function()
    it('should return current_component for split layout', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_SPLIT
      view._current_component = 'current'
      view._patch_component = 'patch'

      eq('current', view:get_navigatable_component())
    end)

    it('should return patch_component for unified layout', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
      view._current_component = 'current'
      view._patch_component = 'patch'

      eq('patch', view:get_navigatable_component())
    end)

    it('should return patch_component for nil layout', function()
      local view = ProjectDiffView()
      view._layout_type = nil
      view._patch_component = 'patch'

      eq('patch', view:get_navigatable_component())
    end)
  end)

  describe('destroy', function()
    it('should be idempotent (safe to call multiple times)', function()
      local view = ProjectDiffView()
      view._component_group = { unmount = function() end }
      view._context = { restore_window_options = function() end }
      view._destroyed = false

      view:destroy()
      view:destroy() -- second call should not error
      assert.is_true(view._destroyed)
    end)

    it('should set _destroyed to true', function()
      local view = ProjectDiffView()
      view._component_group = { unmount = function() end }
      view._context = { restore_window_options = function() end }
      view._destroyed = false

      assert.is_false(view._destroyed)
      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should increment _update_gen to invalidate background enrichment', function()
      local view = ProjectDiffView()
      view._component_group = { unmount = function() end }
      view._context = { restore_window_options = function() end }
      view._destroyed = false

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
      view._component_group = { unmount = function() end }
      view._context = { restore_window_options = function() end }
      view._destroyed = false

      view:destroy()
      eq(1, cleanup1_calls)
      eq(1, cleanup2_calls)
      -- Second call is a no-op (idempotent)
      view:destroy()
      eq(1, cleanup1_calls)
      eq(1, cleanup2_calls)
    end)
  end)
  describe('Hunk Navigation', function()
    describe('get_current_mark_index', function()
      it('should return nil,0 when no marks', function()
        local navigation = require('vgit.core.navigation')
        local index, count = navigation.get_mark_index({}, 1)
        assert.is_nil(index)
        eq(0, count)
      end)

      it('should return correct index when cursor inside a mark', function()
        local navigation = require('vgit.core.navigation')
        local marks = { { top = 5, bot = 10 }, { top = 20, bot = 30 } }
        local index, count = navigation.get_mark_index(marks, 7)
        eq(1, index)
        eq(2, count)
      end)

      it('should return previous index when cursor between marks', function()
        local navigation = require('vgit.core.navigation')
        local marks = { { top = 5, bot = 10 }, { top = 20, bot = 30 } }
        local index, count = navigation.get_mark_index(marks, 15)
        eq(1, index)
        eq(2, count)
      end)

      it('should return last index when cursor after all marks', function()
        local navigation = require('vgit.core.navigation')
        local marks = { { top = 5, bot = 10 }, { top = 20, bot = 30 } }
        local index, count = navigation.get_mark_index(marks, 100)
        eq(2, index)
        eq(2, count)
      end)

      it('should return 1 when cursor before first mark', function()
        local navigation = require('vgit.core.navigation')
        local marks = { { top = 10, bot = 15 } }
        local index, count = navigation.get_mark_index(marks, 1)
        eq(1, index)
        eq(1, count)
      end)
    end)

    describe('hunk_down', function()
      it('should return early if active component is nil', function()
        local view = ProjectDiffView()
        view._patch_component = nil
        view._layout_type = nil
        view:hunk_down() -- should not error
      end)

      it('should return early if active component is invalid', function()
        local view = ProjectDiffView()
        view._patch_component = {
          is_valid = function()
            return false
          end,
        }
        view:hunk_down() -- should not error
      end)

      it('should delegate to patch_component for unified layout', function()
        local called = false
        local view = ProjectDiffView()
        view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
        view._patch_component = {
          is_valid = function()
            return true
          end,
          hunk_down = function()
            called = true
          end,
          get_marks = function()
            return {}
          end,
          get_lnum = function()
            return 1
          end,
        }

        view:hunk_down()
        assert.is_true(called)
      end)

      it('should delegate to current_component for split layout', function()
        local patch_called = false
        local current_called = false
        local view = ProjectDiffView()
        view._layout_type = ProjectDiffView.LAYOUT_SPLIT
        view._patch_component = {
          is_valid = function()
            return true
          end,
          hunk_down = function()
            patch_called = true
          end,
          get_marks = function()
            return {}
          end,
          get_lnum = function()
            return 1
          end,
        }
        view._current_component = {
          is_valid = function()
            return true
          end,
          hunk_down = function()
            current_called = true
          end,
          get_marks = function()
            return {}
          end,
          get_lnum = function()
            return 1
          end,
        }

        view:hunk_down()
        assert.is_false(patch_called)
        assert.is_true(current_called)
      end)

      it('should update statusline after navigation', function()
        local statusline_mod = require('vgit.core.statusline_state')
        local set_hunk_called_with = nil
        local original = statusline_mod.set_hunk
        statusline_mod.set_hunk = function(hunk)
          set_hunk_called_with = hunk
        end

        local view = ProjectDiffView()
        view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
        view._patch_component = {
          is_valid = function()
            return true
          end,
          hunk_down = function() end,
          get_marks = function()
            return { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
          end,
          get_lnum = function()
            return 3
          end,
        }

        view:hunk_down()

        assert.is_not_nil(set_hunk_called_with)
        eq(1, set_hunk_called_with.index)
        eq(2, set_hunk_called_with.count)

        statusline_mod.set_hunk = original
      end)
    end)

    describe('hunk_up', function()
      it('should return early if active component is nil', function()
        local view = ProjectDiffView()
        view._patch_component = nil
        view._layout_type = nil
        view:hunk_up() -- should not error
      end)

      it('should return early if active component is invalid', function()
        local view = ProjectDiffView()
        view._patch_component = {
          is_valid = function()
            return false
          end,
        }
        view:hunk_up() -- should not error
      end)

      it('should delegate to patch_component for unified layout', function()
        local called = false
        local view = ProjectDiffView()
        view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
        view._patch_component = {
          is_valid = function()
            return true
          end,
          hunk_up = function()
            called = true
          end,
          get_marks = function()
            return {}
          end,
          get_lnum = function()
            return 1
          end,
        }

        view:hunk_up()
        assert.is_true(called)
      end)

      it('should delegate to current_component for split layout', function()
        local patch_called = false
        local current_called = false
        local view = ProjectDiffView()
        view._layout_type = ProjectDiffView.LAYOUT_SPLIT
        view._patch_component = {
          is_valid = function()
            return true
          end,
          hunk_up = function()
            patch_called = true
          end,
          get_marks = function()
            return {}
          end,
          get_lnum = function()
            return 1
          end,
        }
        view._current_component = {
          is_valid = function()
            return true
          end,
          hunk_up = function()
            current_called = true
          end,
          get_marks = function()
            return {}
          end,
          get_lnum = function()
            return 1
          end,
        }

        view:hunk_up()
        assert.is_false(patch_called)
        assert.is_true(current_called)
      end)

      it('should update statusline after navigation', function()
        local statusline_mod = require('vgit.core.statusline_state')
        local set_hunk_called_with = nil
        local original = statusline_mod.set_hunk
        statusline_mod.set_hunk = function(hunk)
          set_hunk_called_with = hunk
        end

        local view = ProjectDiffView()
        view._layout_type = ProjectDiffView.LAYOUT_UNIFIED
        view._patch_component = {
          is_valid = function()
            return true
          end,
          hunk_up = function() end,
          get_marks = function()
            return { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
          end,
          get_lnum = function()
            return 12
          end,
        }

        view:hunk_up()

        assert.is_not_nil(set_hunk_called_with)
        eq(2, set_hunk_called_with.index)
        eq(2, set_hunk_called_with.count)

        statusline_mod.set_hunk = original
      end)
    end)
  end)

  describe('_build_diff_file_entries data invariants', function()
    local diff_invariants = require('tests.helpers.diff_invariants')
    local Diff = require('vgit.core.diff.Diff')
    local GitHunk = require('vgit.git.GitHunk')
    local PatchLineBuilder = require('vgit.ui.components.PatchLineBuilder')

    local function make_hunk(header, diff_lines)
      local hunk = GitHunk(header)
      for _, line in ipairs(diff_lines) do
        hunk:push(line)
      end
      return hunk
    end

    local function make_real_diff_entry(filename, filetype, hunks, current_lines)
      local diff = Diff():generate_unified(hunks, current_lines)
      return {
        type = 'diff_file',
        filename = filename,
        filetype = filetype,
        diff = diff,
        original_lines = {},
        current_lines = current_lines,
      }
    end

    it('should produce entries whose diff marks pass ascending + bounds invariants', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED

      local hunk = make_hunk('@@ -1,2 +1,3 @@', { ' line1', '-old', '+new', '+added' })
      local diff = Diff():generate_unified({ hunk }, { 'line1', 'new', 'added' })

      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'a.lua', filetype = 'lua' },
                diff = diff,
                original_lines = { 'line1', 'old' },
                current_lines = { 'line1', 'new', 'added' },
              },
            },
          },
        },
      }

      local mock_repo = {
        get_path = function()
          return '/tmp'
        end,
        diff = function()
          return {}
        end,
      }
      local entries = view:_build_diff_file_entries(mock_repo, data)

      eq(1, #entries)
      diff_invariants.assert_marks_ascending(entries[1].diff.marks)
      diff_invariants.assert_marks_within_bounds(entries[1].diff.marks, #entries[1].diff.lines)
    end)

    it('should produce entries whose lnum_changes pass bounds invariants', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED

      local hunk = make_hunk('@@ -1,1 +1,2 @@', { '-removed', '+changed', '+added' })
      local diff = Diff():generate_unified({ hunk }, { 'changed', 'added' })

      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'b.lua', filetype = 'lua' },
                diff = diff,
                original_lines = { 'removed' },
                current_lines = { 'changed', 'added' },
              },
            },
          },
        },
      }

      local mock_repo = {
        get_path = function()
          return '/tmp'
        end,
        diff = function()
          return {}
        end,
      }
      local entries = view:_build_diff_file_entries(mock_repo, data)

      eq(1, #entries)
      diff_invariants.assert_lnum_changes_within_bounds(entries[1].diff.lnum_changes, #entries[1].diff.lines)
    end)

    it('should produce entries whose stat is consistent with lnum_changes', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED

      local hunk = make_hunk('@@ -1,3 +1,3 @@', { ' ctx', '-old', '+new', ' ctx2' })
      local diff = Diff():generate_unified({ hunk }, { 'ctx', 'new', 'ctx2' })

      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'c.lua', filetype = 'lua' },
                diff = diff,
                original_lines = { 'ctx', 'old', 'ctx2' },
                current_lines = { 'ctx', 'new', 'ctx2' },
              },
            },
          },
        },
      }

      local mock_repo = {
        get_path = function()
          return '/tmp'
        end,
        diff = function()
          return {}
        end,
      }
      local entries = view:_build_diff_file_entries(mock_repo, data)

      eq(1, #entries)
      diff_invariants.assert_stat_consistency(entries[1].diff.stat, entries[1].diff.lnum_changes)
    end)

    it('should produce valid patch marks when entries are piped through build_patch_lines_from_entries', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED

      local hunk = make_hunk('@@ -1,2 +1,3 @@', { ' ctx', '-old', '+new', '+added' })
      local diff = Diff():generate_unified({ hunk }, { 'ctx', 'new', 'added' })

      local diff_file_entries = {
        make_real_diff_entry('a.lua', 'lua', { hunk }, { 'ctx', 'new', 'added' }),
      }
      -- Use the real diff from generate_unified
      diff_file_entries[1].diff = diff

      local lines, _, _, marks = PatchLineBuilder.build(diff_file_entries)

      assert.is_true(#marks > 0)
      diff_invariants.assert_patch_marks(marks, #lines)
    end)

    it('should produce ascending marks across multiple entries piped through patch pipeline', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED

      local hunk1 = make_hunk('@@ -1,1 +1,2 @@', { '-old', '+new', '+added' })
      local hunk2 = make_hunk('@@ -1,1 +1,1 @@', { '-removed', '+changed' })

      local entry1 = make_real_diff_entry('a.lua', 'lua', { hunk1 }, { 'new', 'added' })
      local entry2 = make_real_diff_entry('b.lua', 'lua', { hunk2 }, { 'changed' })

      local lines, _, _, marks = PatchLineBuilder.build({ entry1, entry2 })

      assert.is_true(#marks >= 2)
      diff_invariants.assert_patch_marks(marks, #lines)
    end)

    it('should pass full unified diff invariants for each precomputed entry', function()
      local view = ProjectDiffView()
      view._layout_type = ProjectDiffView.LAYOUT_UNIFIED

      local hunk = make_hunk('@@ -1,3 +1,4 @@', { ' a', '-b', '+c', '+d', ' e' })
      local diff = Diff():generate_unified({ hunk }, { 'a', 'c', 'd', 'e' })

      local data = {
        entries = {
          {
            entries = {
              {
                status = { filename = 'full.lua', filetype = 'lua' },
                diff = diff,
                original_lines = { 'a', 'b', 'e' },
                current_lines = { 'a', 'c', 'd', 'e' },
              },
            },
          },
        },
      }

      local mock_repo = {
        get_path = function()
          return '/tmp'
        end,
        diff = function()
          return {}
        end,
      }
      local entries = view:_build_diff_file_entries(mock_repo, data)

      eq(1, #entries)
      diff_invariants.assert_unified_diff(entries[1].diff)
    end)
  end)
end)
