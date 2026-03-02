local eq = assert.are.same

describe('StashView:', function()
  local StashView

  before_each(function()
    StashView = require('vgit.features.screens.StashView')
  end)

  local function make_commit(revision, message, hash)
    return {
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

  describe('_build_stash_groups', function()
    it('should build a single group named Stashes', function()
      local view = StashView()
      local stashes = {
        make_commit('stash@{0}', 'WIP on main'),
        make_commit('stash@{1}', 'feature work'),
      }
      local groups = view:_build_stash_groups(stashes)

      eq(1, #groups)
      eq('Stashes', groups[1].value)
      assert.is_true(groups[1].open)
    end)

    it('should build one item per stash', function()
      local view = StashView()
      local stashes = {
        make_commit('stash@{0}', 'WIP on main'),
        make_commit('stash@{1}', 'feature work'),
        make_commit('stash@{2}', 'temp save'),
      }
      local groups = view:_build_stash_groups(stashes)

      eq(3, #groups[1].items)
    end)

    it('should format item value as revision: message', function()
      local view = StashView()
      local commit = make_commit('stash@{0}', 'WIP on main')
      local groups = view:_build_stash_groups({ commit })

      eq('stash@{0}: WIP on main', groups[1].items[1].value)
    end)

    it('should store commit in item entry', function()
      local view = StashView()
      local commit = make_commit('stash@{0}', 'WIP on main', 'deadbeef')
      local groups = view:_build_stash_groups({ commit })

      local entry = groups[1].items[1].entry
      eq('stash', entry.type)
      eq(commit, entry.commit)
    end)

    it('should handle a stash with no context revision gracefully', function()
      local view = StashView()
      local commit = {
        hash = 'abc',
        message = 'some work',
        context = {},
      }
      local groups = view:_build_stash_groups({ commit })

      eq(1, #groups[1].items)
      -- value should contain '?: some work'
      assert.is_true(groups[1].items[1].value:find('some work') ~= nil)
    end)

    it('should return empty items for an empty stash list', function()
      local view = StashView()
      local groups = view:_build_stash_groups({})

      eq(1, #groups)
      eq(0, #groups[1].items)
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
      view._layout_type = StashView.LAYOUT_SPLIT
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

  describe('get_key', function()
    it('should return string key as-is', function()
      local view = StashView()
      eq('a', view:get_key('a'))
    end)

    it('should return key field from table', function()
      local view = StashView()
      eq('p', view:get_key({ key = 'p', desc = 'Pop' }))
    end)

    it('should return nil for nil input', function()
      local view = StashView()
      assert.is_nil(view:get_key(nil))
    end)
  end)

  describe('_get_current_commit', function()
    it('should return nil when tree_component is nil', function()
      local view = StashView()
      view._tree_component = nil
      assert.is_nil(view:_get_current_commit())
    end)

    it('should return nil when get_selected_entry returns nil', function()
      local view = StashView()
      view._tree_component = {
        is_valid = function()
          return true
        end,
        get_selected_entry = function()
          return nil
        end,
      }
      assert.is_nil(view:_get_current_commit())
    end)

    it('should return commit from item.entry.commit', function()
      local commit = make_commit('stash@{0}')
      local view = StashView()
      view._tree_component = {
        is_valid = function()
          return true
        end,
        get_selected_entry = function()
          return { entry = { commit = commit } }
        end,
      }
      eq(commit, view:_get_current_commit())
    end)

    it('should return commit when item has commit field directly', function()
      local commit = make_commit('stash@{0}')
      local view = StashView()
      view._tree_component = {
        is_valid = function()
          return true
        end,
        get_selected_entry = function()
          return { commit = commit }
        end,
      }
      eq(commit, view:_get_current_commit())
    end)

    it('should return _current_commit fallback when tree_component is invalid', function()
      local commit = make_commit('stash@{0}')
      local view = StashView()
      view._tree_component = {
        is_valid = function()
          return false
        end,
        get_selected_entry = function()
          return { entry = { commit = commit } }
        end,
      }
      view._current_commit = commit
      eq(commit, view:_get_current_commit())
    end)
  end)

  describe('_refresh_stash_list', function()
    it('should return early without error when repo is nil', function()
      local view = StashView()
      view._repo = nil
      -- Should not crash
      view:_refresh_stash_list()
    end)

    it('should clear the patch cache before fetching', function()
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        stash_list = function()
          return {}, nil
        end,
      }
      view._patch_cache = { ['stash@{0}'] = {}, ['stash@{1}'] = {} }
      view._tree_component = {
        is_valid = function()
          return false
        end,
      }
      -- Empty list → destroy() is called, but we verify cache was cleared first
      view._component_manager = { destroy = function() end }
      view._patch_component = { component_will_unmount = function() end }
      view._tree_component = { component_will_unmount = function() end }
      view:_refresh_stash_list()
      local count = 0
      for _ in pairs(view._patch_cache) do
        count = count + 1
      end
      eq(0, count)
    end)

    it('should call destroy when the refreshed stash list is empty', function()
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        stash_list = function()
          return {}, nil
        end,
      }
      view._component_manager = { destroy = function() end }
      view._patch_component = { component_will_unmount = function() end }
      view._tree_component = { component_will_unmount = function() end }
      view:_refresh_stash_list()
      assert.is_true(view._destroyed)
    end)

    it('should not crash when git_stash.list returns an error', function()
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        stash_list = function()
          return nil, { 'list error' }
        end,
      }
      -- Should not crash
      view:_refresh_stash_list()
    end)

    it('should call set_list on the tree component with rebuilt groups', function()
      local set_list_groups = nil
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
        stash_list = function()
          return { make_commit('stash@{0}', 'WIP') }, nil
        end,
      }
      view._tree_component = {
        is_valid = function()
          return true
        end,
        set_list = function(_, groups)
          set_list_groups = groups
        end,
      }
      view:_refresh_stash_list()
      assert.is_not_nil(set_list_groups)
      eq(1, #set_list_groups)
      eq('Stashes', set_list_groups[1].value)
    end)
  end)

  describe('_update_patch', function()
    it('should do nothing when commit is nil', function()
      local view = StashView()
      view:_update_patch(nil)
      assert.is_nil(view._current_commit)
      eq(0, view._update_gen)
    end)

    it('should set _current_commit to the given commit', function()
      local commit = make_commit('stash@{0}')
      local view = StashView()
      -- Override to avoid real git calls
      view._build_diff_file_entries_for_commit = function()
        return {}
      end
      view._patch_component = {
        is_valid = function()
          return false
        end,
        set_props = function() end,
      }
      view:_update_patch(commit)
      eq(commit, view._current_commit)
    end)

    it('should serve from cache on a cache hit without calling git', function()
      local commit = make_commit('stash@{0}')
      local cached = {
        { type = 'diff_file', filename = 'a.lua', filetype = 'lua', diff = {}, original_lines = {}, current_lines = {} },
      }
      local set_props_data = nil
      local git_called = false

      local view = StashView()
      view._patch_cache = { ['stash@{0}'] = cached }
      view._build_diff_file_entries_for_commit = function()
        git_called = true
        return {}
      end
      view._patch_component = {
        is_valid = function()
          return true
        end,
        set_props = function(_, props)
          set_props_data = props
        end,
      }
      view:_update_patch(commit)
      assert.is_false(git_called)
      eq(cached, set_props_data.hunk_entries)
    end)

    it('should store result in cache on a cache miss', function()
      local commit = make_commit('stash@{0}')
      local mock_entries = {
        { type = 'diff_file', filename = 'a.lua', filetype = 'lua', diff = {}, original_lines = {}, current_lines = {} },
      }

      local view = StashView()
      view._build_diff_file_entries_for_commit = function()
        return mock_entries
      end
      view._patch_component = {
        is_valid = function()
          return false
        end,
        set_props = function() end,
      }
      view:_update_patch(commit)
      eq(mock_entries, view._patch_cache['stash@{0}'])
    end)

    it('should not cache or render when gen is stale (concurrent navigation)', function()
      local commit = make_commit('stash@{0}')
      local set_props_called = false

      local view = StashView()
      -- Simulate another _update_patch call arriving during the git subprocess
      view._build_diff_file_entries_for_commit = function()
        view._update_gen = view._update_gen + 1 -- bump gen, making current gen stale
        return {}
      end
      view._patch_component = {
        is_valid = function()
          return true
        end,
        set_props = function()
          set_props_called = true
        end,
      }
      view:_update_patch(commit)
      assert.is_false(set_props_called)
      -- Cache should NOT be populated with stale data
      assert.is_nil(view._patch_cache['stash@{0}'])
    end)
  end)

  describe('destroy', function()
    it('should be idempotent (safe to call multiple times)', function()
      local view = StashView()
      view._component_manager = { destroy = function() end }
      view._patch_component = { component_will_unmount = function() end }
      view._tree_component = { component_will_unmount = function() end }

      view:destroy()
      view:destroy() -- second call should not error
    end)

    it('should call each debounce cleanup function exactly once', function()
      local cleanup1_calls = 0
      local cleanup2_calls = 0
      local view = StashView()
      view._debounce_cleanups = {
        function()
          cleanup1_calls = cleanup1_calls + 1
        end,
        function()
          cleanup2_calls = cleanup2_calls + 1
        end,
      }
      view._component_manager = { destroy = function() end }
      view._patch_component = { component_will_unmount = function() end }
      view._tree_component = { component_will_unmount = function() end }

      view:destroy()
      eq(1, cleanup1_calls)
      eq(1, cleanup2_calls)
      -- Second call is a no-op (idempotent)
      view:destroy()
      eq(1, cleanup1_calls)
      eq(1, cleanup2_calls)
    end)
  end)

  describe('_get_current_mark_index', function()
    it('should return nil when marks are empty', function()
      local view = StashView()
      local component = {
        get_marks = function()
          return {}
        end,
        get_lnum = function()
          return 1
        end,
      }
      local index, count = view:_get_current_mark_index(component)
      assert.is_nil(index)
      eq(0, count)
    end)

    it('should return first hunk index when cursor is before first hunk', function()
      local view = StashView()
      local marks = { { top = 10, bot = 15 }, { top = 20, bot = 25 } }
      local component = {
        get_marks = function()
          return marks
        end,
        get_lnum = function()
          return 1
        end,
      }
      local index, count = view:_get_current_mark_index(component)
      eq(1, index)
      eq(2, count)
    end)

    it('should return current hunk index when cursor is inside a hunk', function()
      local view = StashView()
      local marks = { { top = 10, bot = 15 }, { top = 20, bot = 25 } }
      local component = {
        get_marks = function()
          return marks
        end,
        get_lnum = function()
          return 12
        end,
      }
      local index, count = view:_get_current_mark_index(component)
      eq(1, index)
      eq(2, count)
    end)

    it('should return previous hunk index when cursor is between hunks', function()
      local view = StashView()
      local marks = { { top = 10, bot = 15 }, { top = 20, bot = 25 } }
      local component = {
        get_marks = function()
          return marks
        end,
        get_lnum = function()
          return 17
        end,
      }
      local index, count = view:_get_current_mark_index(component)
      eq(1, index)
      eq(2, count)
    end)

    it('should return last hunk index when cursor is after last hunk', function()
      local view = StashView()
      local marks = { { top = 10, bot = 15 }, { top = 20, bot = 25 } }
      local component = {
        get_marks = function()
          return marks
        end,
        get_lnum = function()
          return 30
        end,
      }
      local index, count = view:_get_current_mark_index(component)
      eq(2, index)
      eq(2, count)
    end)
  end)

  describe('hunk_down', function()
    local statusline_mod
    local original_set_hunk

    before_each(function()
      statusline_mod = require('vgit.core.statusline_state')
      original_set_hunk = statusline_mod.set_hunk
      statusline_mod.set_hunk = function() end
    end)

    after_each(function()
      statusline_mod.set_hunk = original_set_hunk
    end)

    it('should return early if patch_component is nil', function()
      local view = StashView()
      view._patch_component = nil
      view:hunk_down()
    end)

    it('should return early if patch_component is invalid', function()
      local view = StashView()
      view._patch_component = {
        is_valid = function()
          return false
        end,
      }
      view:hunk_down()
    end)

    it('should call hunk_down on component and update statusline', function()
      local hunk_down_called = false
      local set_hunk_called_with = nil

      local view = StashView()
      view._patch_component = {
        is_valid = function()
          return true
        end,
        hunk_down = function(_, pos)
          hunk_down_called = true
        end,
        get_marks = function()
          return { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        end,
        get_lnum = function()
          return 3
        end,
      }
      statusline_mod.set_hunk = function(hunk)
        set_hunk_called_with = hunk
      end

      view:hunk_down()

      assert.is_true(hunk_down_called)
      eq(1, set_hunk_called_with.index)
      eq(2, set_hunk_called_with.count)
    end)
  end)

  describe('_move_to_first_stash', function()
    local function make_tree_mock(shadow_list)
      return {
        find_list_item = function(_, callback)
          for lnum, item in ipairs(shadow_list) do
            if callback(item) then return item, lnum end
          end
          return nil, nil
        end,
        set_lnum = function() end,
      }
    end

    it('should do nothing when tree_component is nil', function()
      local view = StashView()
      view._tree_component = nil
      view:_move_to_first_stash()
    end)

    it('should call set_lnum with the lnum of the first item that has entry.commit', function()
      local set_lnum_called_with = nil
      local commit = make_commit('stash@{0}')
      local shadow_list = {
        { value = 'Stashes' },
        { value = 'stash@{0}: WIP', entry = { type = 'stash', commit = commit } },
        { value = 'stash@{1}: more', entry = { type = 'stash', commit = make_commit('stash@{1}') } },
      }
      local view = StashView()
      local mock = make_tree_mock(shadow_list)
      mock.set_lnum = function(_, lnum)
        set_lnum_called_with = lnum
      end
      view._tree_component = mock
      view:_move_to_first_stash()
      eq(2, set_lnum_called_with)
    end)

    it('should skip leading items without entry.commit', function()
      local set_lnum_called_with = nil
      local shadow_list = {
        { value = 'Stashes' },
        { value = 'sub-header' },
        { value = 'stash@{0}: WIP', entry = { commit = make_commit('stash@{0}') } },
      }
      local view = StashView()
      local mock = make_tree_mock(shadow_list)
      mock.set_lnum = function(_, lnum)
        set_lnum_called_with = lnum
      end
      view._tree_component = mock
      view:_move_to_first_stash()
      eq(3, set_lnum_called_with)
    end)

    it('should not call set_lnum when no items have entry.commit', function()
      local set_lnum_called = false
      local shadow_list = {
        { value = 'Stashes' },
        { value = 'Empty' },
      }
      local view = StashView()
      local mock = make_tree_mock(shadow_list)
      mock.set_lnum = function()
        set_lnum_called = true
      end
      view._tree_component = mock
      view:_move_to_first_stash()
      assert.is_false(set_lnum_called)
    end)
  end)

  describe('hunk_up', function()
    local statusline_mod
    local original_set_hunk

    before_each(function()
      statusline_mod = require('vgit.core.statusline_state')
      original_set_hunk = statusline_mod.set_hunk
      statusline_mod.set_hunk = function() end
    end)

    after_each(function()
      statusline_mod.set_hunk = original_set_hunk
    end)

    it('should return early if patch_component is nil', function()
      local view = StashView()
      view._patch_component = nil
      view:hunk_up()
    end)

    it('should return early if patch_component is invalid', function()
      local view = StashView()
      view._patch_component = {
        is_valid = function()
          return false
        end,
      }
      view:hunk_up()
    end)

    it('should call hunk_up on component and update statusline', function()
      local hunk_up_called = false
      local set_hunk_called_with = nil

      local view = StashView()
      view._patch_component = {
        is_valid = function()
          return true
        end,
        hunk_up = function(_, pos)
          hunk_up_called = true
        end,
        get_marks = function()
          return { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        end,
        get_lnum = function()
          return 1
        end, -- cursor position AFTER hunk_up moves to first hunk
      }
      statusline_mod.set_hunk = function(hunk)
        set_hunk_called_with = hunk
      end

      view:hunk_up()

      assert.is_true(hunk_up_called)
      eq(1, set_hunk_called_with.index)
      eq(2, set_hunk_called_with.count)
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
