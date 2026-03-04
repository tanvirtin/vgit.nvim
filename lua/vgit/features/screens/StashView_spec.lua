local eq = assert.are.same

describe('StashView:', function()
  local StashView

  before_each(function()
    StashView = require('vgit.features.screens.StashView')
  end)

  local function make_commit(revision, message, hash)
    local commit = {
      hash = hash or 'abc1234',
      parent_hash = 'parent000',
      author = 'Test Author',
      author_mail = 'test@example.com',
      author_time = 1700000000,
      message = message or 'WIP on main: test changes',
      repository = '/tmp/repo',
      context = {
        revision = revision or 'stash@{0}',
        is_stash = true,
      },
    }
    function commit:age()
      return { unit = 3, how_long = 'days', display = '3 days ago' }
    end
    return commit
  end

  describe('create', function()
    it('should return false when no data is provided', function()
      local view = StashView()
      local result = view:create(nil)
      assert.is_false(result)
    end)

    it('should return false when data is not a table', function()
      local view = StashView()
      local result = view:create('invalid')
      assert.is_false(result)
    end)

    it('should return false when stashes is missing', function()
      local view = StashView()
      local result = view:create({})
      assert.is_false(result)
    end)

    it('should return false when stashes is an empty table', function()
      local view = StashView()
      local result = view:create({ stashes = {} })
      assert.is_false(result)
    end)

    it('should return false when stashes is not a table', function()
      local view = StashView()
      local result = view:create({ stashes = 'bad' })
      assert.is_false(result)
    end)
  end)

  describe('_build_items', function()
    it('should build one item per stash', function()
      local view = StashView()
      local stashes = {
        make_commit('stash@{0}', 'WIP on main'),
        make_commit('stash@{1}', 'feature work'),
        make_commit('stash@{2}', 'temp save'),
      }
      local items = view:_build_items(stashes)

      eq(3, #items)
    end)

    it('should format item label with index and message', function()
      local view = StashView()
      local commit = make_commit('stash@{0}', 'WIP on main: abc1234 Fix bug')
      local items = view:_build_items({ commit })

      local label = items[1].label
      assert.is_true(label:find('{0}') ~= nil)
      assert.is_true(label:find('Fix bug') ~= nil)
    end)

    it('should include branch and age in description', function()
      local view = StashView()
      local commit = make_commit('stash@{0}', 'WIP on main: abc1234 Fix bug')
      local items = view:_build_items({ commit })

      local desc = items[1].description
      assert.is_true(desc:find('main') ~= nil)
      assert.is_true(desc:find('3 days ago') ~= nil)
    end)

    it('should set value with commit entry', function()
      local view = StashView()
      local commit = make_commit('stash@{0}', 'WIP on main', 'deadbeef')
      local items = view:_build_items({ commit })

      local value = items[1].value
      eq('stash', value.type)
      eq(commit, value.commit)
    end)

    it('should handle a stash with no context revision gracefully', function()
      local view = StashView()
      local commit = {
        hash = 'abc',
        message = 'some work',
        context = {},
      }
      function commit:age()
        return { unit = 1, how_long = 'hour', display = '1 hour ago' }
      end
      local items = view:_build_items({ commit })

      eq(1, #items)
      assert.is_true(items[1].label:find('some work') ~= nil)
    end)

    it('should return empty items for an empty stash list', function()
      local view = StashView()
      local items = view:_build_items({})

      eq(0, #items)
    end)
  end)

  describe('_format_stash_index', function()
    it('should extract numeric index from stash@{N}', function()
      local view = StashView()
      eq('{0}', view:_format_stash_index('stash@{0}'))
      eq('{5}', view:_format_stash_index('stash@{5}'))
      eq('{12}', view:_format_stash_index('stash@{12}'))
    end)

    it('should return original string when format does not match', function()
      local view = StashView()
      eq('?', view:_format_stash_index('?'))
      eq('unknown', view:_format_stash_index('unknown'))
    end)
  end)

  describe('_parse_stash_message', function()
    it('should parse WIP on branch format', function()
      local view = StashView()
      local branch, message = view:_parse_stash_message('WIP on main: abc1234 Fix bug')
      eq('main', branch)
      eq('Fix bug', message)
    end)

    it('should parse WIP on branch with complex branch name', function()
      local view = StashView()
      local branch, message = view:_parse_stash_message('WIP on feature/auth-flow: def5678 Add login page')
      eq('feature/auth-flow', branch)
      eq('Add login page', message)
    end)

    it('should parse On branch format (custom message)', function()
      local view = StashView()
      local branch, message = view:_parse_stash_message('On main: my custom stash message')
      eq('main', branch)
      eq('my custom stash message', message)
    end)

    it('should return nil branch for unrecognized format', function()
      local view = StashView()
      local branch, message = view:_parse_stash_message('some random message')
      assert.is_nil(branch)
      eq('some random message', message)
    end)

    it('should handle empty message', function()
      local view = StashView()
      local branch, message = view:_parse_stash_message('')
      assert.is_nil(branch)
      eq('', message)
    end)
  end)

  describe('_build_diff_file_entries_for_commit', function()
    it('should return empty table when repo is nil', function()
      local view = StashView()
      view._repo = nil
      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))
      eq(0, #entries)
    end)

    it('should return empty table when commit has no revision', function()
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {}
        end,
      }
      local commit = { hash = 'abc', message = 'test', context = {} }
      local entries = view:_build_diff_file_entries_for_commit(commit)
      eq(0, #entries)
    end)

    it('should return empty table when repo:diff returns error', function()
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return nil, { 'git diff failed' }
        end,
      }
      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))
      eq(0, #entries)
    end)

    it('should return empty table when repo:diff returns no entries', function()
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {}
        end,
      }
      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))
      eq(0, #entries)
    end)

    it('should return diff_file entries from repo:diff', function()
      local view = StashView()
      local mock_file_diffs = {
        {
          filename = 'foo.lua',
          filetype = 'lua',
          diff = { lines = { 'content' }, lnum_changes = {}, marks = {} },
          original_lines = { 'old' },
          current_lines = { 'new' },
        },
      }
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return mock_file_diffs
        end,
      }
      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))
      eq(1, #entries)
      eq('diff_file', entries[1].type)
      eq('foo.lua', entries[1].filename)
      eq('lua', entries[1].filetype)
      eq({ 'old' }, entries[1].original_lines)
      eq({ 'new' }, entries[1].current_lines)
    end)

    it('should pass correct refs and layout_type to repo:diff', function()
      local view = StashView()
      view._layout_type = 'split'
      local captured_spec
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function(_, spec)
          captured_spec = spec
          return {}
        end,
      }
      view:_build_diff_file_entries_for_commit(make_commit('stash@{2}'))
      eq('range', captured_spec.type)
      eq('stash@{2}^', captured_spec.from)
      eq('stash@{2}', captured_spec.to)
      eq('split', captured_spec.layout_type)
    end)
  end)

  describe('_update_patch', function()
    it('should set _current_commit', function()
      local view = StashView()
      view._repo = {
        get_path = function() return '/tmp/repo' end,
        diff = function() return {} end,
      }
      local commit = make_commit('stash@{0}')
      view:_update_patch(commit)
      eq(commit, view._current_commit)
    end)

    it('should increment _update_gen', function()
      local view = StashView()
      view._repo = {
        get_path = function() return '/tmp/repo' end,
        diff = function() return {} end,
      }
      eq(0, view._update_gen)
      view:_update_patch(make_commit('stash@{0}'))
      eq(1, view._update_gen)
      view:_update_patch(make_commit('stash@{1}'))
      eq(2, view._update_gen)
    end)

    it('should cache entries by revision', function()
      local view = StashView()
      local mock_entries = {
        { filename = 'a.lua', filetype = 'lua', diff = {}, original_lines = {}, current_lines = {} },
      }
      view._repo = {
        get_path = function() return '/tmp/repo' end,
        diff = function() return mock_entries end,
      }

      view:_update_patch(make_commit('stash@{0}'))

      assert.is_not_nil(view._patch_cache['stash@{0}'])
    end)

    it('should use cache on second call with same revision', function()
      local view = StashView()
      local call_count = 0
      view._repo = {
        get_path = function() return '/tmp/repo' end,
        diff = function()
          call_count = call_count + 1
          return {}
        end,
      }

      view:_update_patch(make_commit('stash@{0}'))
      eq(1, call_count)

      view:_update_patch(make_commit('stash@{0}'))
      eq(1, call_count) -- should not call diff again
    end)

    it('should not error when commit is nil', function()
      local view = StashView()
      -- Should not error
      view:_update_patch(nil)
    end)
  end)

  describe('_get_current_revision', function()
    it('should return revision from current commit', function()
      local view = StashView()
      view._current_commit = make_commit('stash@{2}')
      eq('stash@{2}', view:_get_current_revision())
    end)

    it('should return nil when no current commit', function()
      local view = StashView()
      assert.is_nil(view:_get_current_revision())
    end)

    it('should return nil when commit has no context', function()
      local view = StashView()
      view._current_commit = { hash = 'abc', context = {} }
      assert.is_nil(view:_get_current_revision())
    end)
  end)

  describe('_get_current_commit', function()
    it('should return _current_commit when search component is nil', function()
      local view = StashView()
      local commit = make_commit('stash@{0}')
      view._current_commit = commit
      eq(commit, view:_get_current_commit())
    end)

    it('should return _current_commit when search component has no selected item', function()
      local view = StashView()
      local commit = make_commit('stash@{0}')
      view._current_commit = commit
      view._search_component = {
        is_valid = function() return true end,
        get_selected_item = function() return nil end,
      }
      eq(commit, view:_get_current_commit())
    end)

    it('should return commit from selected item when available', function()
      local view = StashView()
      local fallback = make_commit('stash@{1}')
      local selected = make_commit('stash@{0}')
      view._current_commit = fallback
      view._search_component = {
        is_valid = function() return true end,
        get_selected_item = function()
          return { value = { type = 'stash', commit = selected } }
        end,
      }
      eq(selected, view:_get_current_commit())
    end)
  end)

  describe('destroy', function()
    it('should be idempotent (safe to call multiple times)', function()
      local view = StashView()
      view._component_manager = { destroy = function() end }

      view:destroy()
      view:destroy() -- second call should not error
    end)

    it('should set _destroyed to true', function()
      local view = StashView()
      view._component_manager = { destroy = function() end }

      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should call component_manager:destroy()', function()
      local cm_destroyed = false
      local view = StashView()
      view._component_manager = {
        destroy = function()
          cm_destroyed = true
        end,
      }

      view:destroy()
      assert.is_true(cm_destroyed)
    end)

    it('should nil out component_manager and search_component', function()
      local view = StashView()
      view._component_manager = { destroy = function() end }
      view._search_component = {}
      view._patch_component = {}

      view:destroy()
      assert.is_nil(view._component_manager)
      assert.is_nil(view._search_component)
      assert.is_nil(view._patch_component)
    end)

    it('should cleanup debounce functions', function()
      local cleanup_called = false
      local view = StashView()
      view._component_manager = { destroy = function() end }
      view._debounce_cleanups = { function() cleanup_called = true end }

      view:destroy()
      assert.is_true(cleanup_called)
    end)
  end)

  describe('_build_diff_file_entries_for_commit data invariants', function()
    local diff_invariants = require('tests.helpers.diff_invariants')
    local Diff = require('vgit.core.diff.Diff')
    local GitHunk = require('vgit.git.GitHunk')
    local PatchPreviewComponent = require('vgit.ui.components.PatchPreviewComponent')

    local function make_hunk(header, diff_lines)
      local hunk = GitHunk(header)
      for _, line in ipairs(diff_lines) do
        hunk:push(line)
      end
      return hunk
    end

    local function make_real_diff(hunks, current_lines)
      return Diff():generate_unified(hunks, current_lines)
    end

    it('should produce entries with marks passing ascending + bounds invariants', function()
      local hunk = make_hunk('@@ -1,2 +1,3 @@', { ' line1', '-old', '+new', '+added' })
      local diff = make_real_diff({ hunk }, { 'line1', 'new', 'added' })

      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {
            {
              filename = 'stashed.lua',
              filetype = 'lua',
              diff = diff,
              original_lines = { 'line1', 'old' },
              current_lines = { 'line1', 'new', 'added' },
            },
          }
        end,
      }

      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))

      eq(1, #entries)
      eq('diff_file', entries[1].type)
      eq('stashed.lua', entries[1].filename)
      diff_invariants.assert_marks_ascending(entries[1].diff.marks)
      diff_invariants.assert_marks_within_bounds(entries[1].diff.marks, #entries[1].diff.lines)
    end)

    it('should produce entries whose lnum_changes and stat are consistent', function()
      local hunk = make_hunk('@@ -1,1 +1,2 @@', { '-removed', '+changed', '+new' })
      local diff = make_real_diff({ hunk }, { 'changed', 'new' })

      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {
            {
              filename = 'a.lua',
              filetype = 'lua',
              diff = diff,
              original_lines = { 'removed' },
              current_lines = { 'changed', 'new' },
            },
          }
        end,
      }

      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))

      eq(1, #entries)
      diff_invariants.assert_lnum_changes_within_bounds(entries[1].diff.lnum_changes, #entries[1].diff.lines)
      diff_invariants.assert_stat_consistency(entries[1].diff.stat, entries[1].diff.lnum_changes)
    end)

    it('should pass full unified diff invariants on each entry', function()
      local hunk = make_hunk('@@ -1,3 +1,3 @@', { ' ctx', '-old', '+new', ' end' })
      local diff = make_real_diff({ hunk }, { 'ctx', 'new', 'end' })

      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {
            {
              filename = 'full.lua',
              filetype = 'lua',
              diff = diff,
              original_lines = { 'ctx', 'old', 'end' },
              current_lines = { 'ctx', 'new', 'end' },
            },
          }
        end,
      }

      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))

      eq(1, #entries)
      diff_invariants.assert_unified_diff(entries[1].diff)
    end)

    it('should produce valid patch marks when entries piped through build_patch_lines_from_entries', function()
      local hunk1 = make_hunk('@@ -1,1 +1,2 @@', { '-old', '+new', '+added' })
      local hunk2 = make_hunk('@@ -1,1 +1,1 @@', { '-removed', '+changed' })
      local diff1 = make_real_diff({ hunk1 }, { 'new', 'added' })
      local diff2 = make_real_diff({ hunk2 }, { 'changed' })

      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {
            {
              filename = 'a.lua',
              filetype = 'lua',
              diff = diff1,
              original_lines = { 'old' },
              current_lines = { 'new', 'added' },
            },
            {
              filename = 'b.lua',
              filetype = 'lua',
              diff = diff2,
              original_lines = { 'removed' },
              current_lines = { 'changed' },
            },
          }
        end,
      }

      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))

      eq(2, #entries)
      local component = PatchPreviewComponent({})
      local lines, _, _, marks = component:build_patch_lines_from_entries(entries)

      assert.is_true(#marks >= 2)
      diff_invariants.assert_patch_marks(marks, #lines)
    end)

    it('should produce entries with non-nil diff, filename, and filetype', function()
      local hunk = make_hunk('@@ -1,1 +1,1 @@', { '-a', '+b' })
      local diff = make_real_diff({ hunk }, { 'b' })

      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        diff = function()
          return {
            {
              filename = 'typed.lua',
              filetype = 'lua',
              diff = diff,
              original_lines = { 'a' },
              current_lines = { 'b' },
            },
          }
        end,
      }

      local entries = view:_build_diff_file_entries_for_commit(make_commit('stash@{0}'))

      eq(1, #entries)
      eq('diff_file', entries[1].type)
      assert.is_not_nil(entries[1].diff)
      assert.is_not_nil(entries[1].filename)
      assert.is_not_nil(entries[1].filetype)
      assert.is_true(#entries[1].diff.lines > 0)
    end)
  end)
end)
