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

  describe('_build_patch_entries_for_commit', function()
    local git_diff_mod
    local original_range_patch_entries

    before_each(function()
      git_diff_mod = require('vgit.git.git_diff')
      original_range_patch_entries = git_diff_mod.range_patch_entries
    end)

    after_each(function()
      git_diff_mod.range_patch_entries = original_range_patch_entries
    end)

    it('should return empty table when repo is nil', function()
      local view = StashView()
      view._repo = nil
      local entries = view:_build_patch_entries_for_commit(make_commit('stash@{0}'))
      eq(0, #entries)
    end)

    it('should return empty table when commit has no revision', function()
      local view = StashView()
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local commit = { hash = 'abc', message = 'test', context = {} }
      local entries = view:_build_patch_entries_for_commit(commit)
      eq(0, #entries)
    end)

    it('should return empty table when git_diff returns error', function()
      local view = StashView()
      git_diff_mod.range_patch_entries = function()
        return nil, { 'git diff failed' }
      end
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local entries = view:_build_patch_entries_for_commit(make_commit('stash@{0}'))
      eq(0, #entries)
    end)

    it('should return empty table when git_diff returns no entries', function()
      local view = StashView()
      git_diff_mod.range_patch_entries = function()
        return {}
      end
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local entries = view:_build_patch_entries_for_commit(make_commit('stash@{0}'))
      eq(0, #entries)
    end)

    it('should return patch entries from git_diff', function()
      local view = StashView()
      local mock_entries = {
        { type = 'file_header', filename = 'foo.lua', filetype = 'lua' },
        {
          type = 'hunk',
          hunk = { header = '@@ -1,1 +1,1 @@', diff = { '-old', '+new' } },
          filetype = 'lua',
          filename = 'foo.lua',
        },
      }
      git_diff_mod.range_patch_entries = function()
        return mock_entries
      end
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local entries = view:_build_patch_entries_for_commit(make_commit('stash@{0}'))
      eq(2, #entries)
      eq('file_header', entries[1].type)
      eq('foo.lua', entries[1].filename)
      eq('hunk', entries[2].type)
    end)

    it('should pass correct refs (revision^ and revision) to git_diff', function()
      local view = StashView()
      local captured_from, captured_to
      git_diff_mod.range_patch_entries = function(_, from_ref, to_ref)
        captured_from = from_ref
        captured_to = to_ref
        return {}
      end
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      view:_build_patch_entries_for_commit(make_commit('stash@{2}'))
      eq('stash@{2}^', captured_from)
      eq('stash@{2}', captured_to)
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
    local git_stash_mod
    local original_list

    before_each(function()
      git_stash_mod = require('vgit.git.git_stash')
      original_list = git_stash_mod.list
    end)

    after_each(function()
      git_stash_mod.list = original_list
    end)

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
      }
      view._patch_cache = { ['stash@{0}'] = {}, ['stash@{1}'] = {} }
      view._tree_component = {
        is_valid = function()
          return false
        end,
      }
      git_stash_mod.list = function()
        return {}, nil
      end
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
      }
      git_stash_mod.list = function()
        return {}, nil
      end
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
      }
      git_stash_mod.list = function()
        return nil, { 'list error' }
      end
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
      }
      view._tree_component = {
        is_valid = function()
          return true
        end,
        set_list = function(_, groups)
          set_list_groups = groups
        end,
      }
      git_stash_mod.list = function()
        return { make_commit('stash@{0}', 'WIP') }, nil
      end
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
      view._build_patch_entries_for_commit = function()
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
      local cached = { { type = 'hunk', hunk = {}, filetype = 'lua', filename = 'a.lua' } }
      local set_props_data = nil
      local git_called = false

      local view = StashView()
      view._patch_cache = { ['stash@{0}'] = cached }
      view._build_patch_entries_for_commit = function()
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
      eq(cached, set_props_data.patch_entries)
    end)

    it('should store result in cache on a cache miss', function()
      local commit = make_commit('stash@{0}')
      local mock_entries = { { type = 'hunk', hunk = {}, filetype = 'lua', filename = 'a.lua' } }

      local view = StashView()
      view._build_patch_entries_for_commit = function()
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
      view._build_patch_entries_for_commit = function()
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

  describe('_enrich_with_syntax', function()
    it('should exit early when view is destroyed', function()
      local view = StashView()
      view._destroyed = true
      view._repo = {
        file_lines = function()
          error('should not be called')
        end,
      }
      -- Should not call file_lines or error
      view:_enrich_with_syntax(make_commit('stash@{0}'), {
        { type = 'file_header', filename = 'foo.lua', filetype = 'lua' },
      }, 1)
    end)

    it('should exit early when gen is stale', function()
      local view = StashView()
      view._destroyed = false
      view._update_gen = 2 -- current gen is 2, but we pass gen=1
      view._repo = {
        file_lines = function()
          error('should not be called')
        end,
      }
      view:_enrich_with_syntax(make_commit('stash@{0}'), {
        { type = 'file_header', filename = 'foo.lua', filetype = 'lua' },
      }, 1)
    end)

    it('should exit early when repo is nil', function()
      local view = StashView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = nil
      -- Should not error
      view:_enrich_with_syntax(make_commit('stash@{0}'), {
        { type = 'file_header', filename = 'foo.lua', filetype = 'lua' },
      }, 1)
    end)

    it('should exit early when commit has no revision', function()
      local view = StashView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      local commit = { hash = 'abc', context = {} } -- no revision
      -- Should not error
      view:_enrich_with_syntax(commit, {
        { type = 'file_header', filename = 'foo.lua', filetype = 'lua' },
      }, 1)
    end)

    it('should exit early when all file_header entries have filetype text', function()
      local view = StashView()
      view._destroyed = false
      view._update_gen = 1
      view._repo = {
        get_path = function()
          return '/tmp/repo'
        end,
      }
      -- filetype = 'text' entries are skipped, so file_specs will be empty
      local entries = {
        { type = 'file_header', filename = 'README', filetype = 'text' },
        { type = 'hunk', filename = 'README', filetype = 'text', hunk = {} },
      }
      -- Should not call event.all / file_lines, so no coroutine issues
      view:_enrich_with_syntax(make_commit('stash@{0}'), entries, 1)
    end)

    it('should exit early when there are no file_header entries at all', function()
      local view = StashView()
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
      view:_enrich_with_syntax(make_commit('stash@{0}'), entries, 1)
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
      statusline_mod.set_hunk = function(idx, cnt)
        set_hunk_called_with = { idx, cnt }
      end

      view:hunk_down()

      assert.is_true(hunk_down_called)
      eq(1, set_hunk_called_with[1])
      eq(2, set_hunk_called_with[2])
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
      statusline_mod.set_hunk = function(idx, cnt)
        set_hunk_called_with = { idx, cnt }
      end

      view:hunk_up()

      assert.is_true(hunk_up_called)
      eq(1, set_hunk_called_with[1])
      eq(2, set_hunk_called_with[2])
    end)
  end)
end)
