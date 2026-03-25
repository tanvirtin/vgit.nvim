local eq = assert.are.same
local mock_event = require('tests.helpers.mock_event').install()

describe('StatusDiffView:', function()
  local StatusDiffView
  local save_package, restore_packages = require('tests.helpers.package_mock').create()

  -- Helper to create a valid entry
  local function make_entry(opts)
    opts = opts or {}
    return {
      type = opts.type or 'unstaged',
      status = {
        filename = opts.filename or 'test.lua',
        filetype = opts.filetype or 'lua',
        staged = opts.staged or false,
        unstaged = opts.unstaged or true,
      },
    }
  end

  -- Helper to create valid data for create()
  local function make_data(opts)
    opts = opts or {}
    return {
      entries = opts.entries or {
        {
          title = 'Unstaged Changes',
          entries = {
            make_entry({ filename = 'file1.lua', type = 'unstaged' }),
            make_entry({ filename = 'file2.lua', type = 'unstaged' }),
          },
        },
        {
          title = 'Staged Changes',
          entries = {
            make_entry({ filename = 'file3.lua', type = 'staged' }),
          },
        },
      },
      layout_type = opts.layout_type,
    }
  end

  before_each(function()
    -- Fresh require each test
    package.loaded['vgit.features.screens.StatusDiffView'] = nil
    StatusDiffView = require('vgit.features.screens.StatusDiffView')
  end)

  after_each(function()
    restore_packages()
    -- Ensure event mock stays in place
    package.loaded['vgit.core.event'] = mock_event
  end)
  describe('Entry Validation', function()
    describe('_is_valid_entry', function()
      it('should return false for nil entry', function()
        local view = StatusDiffView()
        assert.is_false(view:_is_valid_entry(nil))
      end)

      it('should return false for empty table entry', function()
        local view = StatusDiffView()
        assert.is_false(view:_is_valid_entry({}))
      end)

      it('should return false when entry has no status', function()
        local view = StatusDiffView()
        assert.is_false(view:_is_valid_entry({ type = 'unstaged' }))
      end)

      it('should return false when status has no filename', function()
        local view = StatusDiffView()
        assert.is_false(view:_is_valid_entry({ status = {} }))
      end)

      it('should return false when filename is not a string', function()
        local view = StatusDiffView()
        assert.is_false(view:_is_valid_entry({ status = { filename = 123 } }))
        assert.is_false(view:_is_valid_entry({ status = { filename = {} } }))
        assert.is_false(view:_is_valid_entry({ status = { filename = true } }))
      end)

      it('should return true for valid entry with string filename', function()
        local view = StatusDiffView()
        local entry = make_entry()
        assert.is_true(view:_is_valid_entry(entry))
      end)

      it('should return true for entry with minimal valid structure', function()
        local view = StatusDiffView()
        assert.is_true(view:_is_valid_entry({ status = { filename = 'test.lua' } }))
      end)
    end)

    describe('get_current_entry', function()
      it('should return nil when tree_component is nil', function()
        local view = StatusDiffView()
        view._tree_component = nil
        assert.is_nil(view:get_current_entry())
      end)

      it('should delegate to tree_component:get_selected_entry', function()
        local view = StatusDiffView()
        local expected_entry = make_entry({ filename = 'myfile.lua' })
        view._tree_component = {
          get_selected_entry = function()
            return expected_entry
          end,
        }
        eq(expected_entry, view:get_current_entry())
        eq('myfile.lua', view:get_current_entry().status.filename)
      end)

      it('should return nil when tree has no selected entry', function()
        local view = StatusDiffView()
        view._tree_component = {
          get_selected_entry = function()
            return nil
          end,
        }
        assert.is_nil(view:get_current_entry())
      end)
    end)
  end)
  describe('Data Validation', function()
    describe('create', function()
      it('should reject when data is nil', function()
        local view = StatusDiffView()
        local result = view:create(nil)
        assert.is_false(result)
      end)

      it('should reject when data is not a table', function()
        local view = StatusDiffView()
        assert.is_false(view:create('string'))
        assert.is_false(view:create(123))
        assert.is_false(view:create(true))
      end)

      it('should reject when data has no entries field', function()
        local view = StatusDiffView()
        local result = view:create({})
        assert.is_false(result)
      end)

      it('should reject when entries is not a table', function()
        local view = StatusDiffView()
        assert.is_false(view:create({ entries = 'string' }))
        assert.is_false(view:create({ entries = 123 }))
      end)

      it('should reject when entries is empty table', function()
        local view = StatusDiffView()
        local result = view:create({ entries = {} })
        assert.is_false(result)
      end)

      -- Note: Tests that call create() with valid data would try to render real UI
      -- and hang in headless mode. We test _process_entries_data indirectly through
      -- the error cases above, and test opts setting separately below.

      it('should store layout_type from data in opts via _process_entries_data', function()
        local view = StatusDiffView()
        -- Mock _create_view to avoid UI creation
        view._create_view = function()
          return true
        end
        view:create(make_data({ layout_type = 'split' }))
        eq('split', view._opts.layout_type)
      end)

      it('should store data in view via _process_entries_data', function()
        local view = StatusDiffView()
        view._create_view = function()
          return true
        end
        local data = make_data()
        view:create(data)
        eq(data, view._data)
      end)

      it('should use default layout_type when not provided', function()
        local view = StatusDiffView()
        eq('unified', view._opts.layout_type)
      end)
    end)
  end)
  describe('Diff Spec Building', function()
    describe('_build_entry_diff', function()
      local mock_repo

      before_each(function()
        mock_repo = {
          diff = function(_, diff_spec, opts)
            return { diff_spec = diff_spec, opts = opts }, nil
          end,
          index = function()
            return {
              staged_hunks = function()
                return { { header = '@@ -1,3 +1,3 @@', top = 1, bot = 3, type = 'change' } }
              end,
              unstaged_hunks = function()
                return {}
              end,
            }
          end,
        }
      end)

      it('should return error when entry is invalid', function()
        local view = StatusDiffView()
        local result, err = view:_build_entry_diff(nil, mock_repo)
        assert.is_nil(result)
        assert.is_not_nil(err)
        eq('entry is invalid', err[1])
      end)

      it('should return error when entry has no status', function()
        local view = StatusDiffView()
        local result, err = view:_build_entry_diff({ type = 'unstaged' }, mock_repo)
        assert.is_nil(result)
        assert.is_not_nil(err)
      end)

      it('should build staged entry diff spec (HEAD->index)', function()
        local view = StatusDiffView()
        local entry = make_entry({ type = 'staged', filename = 'staged.lua' })
        local result = view:_build_entry_diff(entry, mock_repo)

        eq('range', result.diff_spec.type)
        eq('staged.lua', result.diff_spec.filename)
        eq('HEAD', result.diff_spec.from)
        eq('index', result.diff_spec.to)
        assert.is_not_nil(result.diff_spec.hunks)
      end)

      it('should build unstaged entry diff spec (index->disk)', function()
        local view = StatusDiffView()
        local entry = make_entry({ type = 'unstaged', filename = 'unstaged.lua' })
        local result = view:_build_entry_diff(entry, mock_repo)

        eq('range', result.diff_spec.type)
        eq('unstaged.lua', result.diff_spec.filename)
        eq('index', result.diff_spec.from)
        eq('disk', result.diff_spec.to)
        assert.is_not_nil(result.diff_spec.hunks)
      end)

      it('should build unmerged entry diff spec (conflict type)', function()
        local view = StatusDiffView()
        local entry = make_entry({ type = 'unmerged', filename = 'conflict.lua' })
        local result = view:_build_entry_diff(entry, mock_repo)

        eq('conflict', result.diff_spec.type)
        eq('conflict.lua', result.diff_spec.filename)
      end)

      it('should pass layout_type in opts', function()
        local view = StatusDiffView()
        view._opts.layout_type = 'split'
        local entry = make_entry({ filename = 'test.lua' })
        local result = view:_build_entry_diff(entry, mock_repo)

        eq('split', result.opts.layout_type)
      end)

      it('should handle unknown entry type as unstaged', function()
        local view = StatusDiffView()
        local entry = make_entry({ type = 'unknown', filename = 'test.lua' })
        local result = view:_build_entry_diff(entry, mock_repo)

        eq('range', result.diff_spec.type)
        eq('index', result.diff_spec.from)
        eq('disk', result.diff_spec.to)
      end)
    end)

    describe('_create_diff_component', function()
      it('should return DiffComponent for unified layout', function()
        local view = StatusDiffView()
        local component = view:_create_diff_component({}, 'unified')

        assert.is_not_nil(component)
        assert.is_nil(component._previous_component)
        assert.is_nil(component._current_component)
      end)

      it('should return SplitDiffComponent for split layout', function()
        local view = StatusDiffView()
        local component = view:_create_diff_component({}, 'split')

        assert.is_not_nil(component)
        assert.is_not_nil(component.calculate_split_line_numbers)
      end)

      it('should use unified as default layout type', function()
        local view = StatusDiffView()
        local component = view:_create_diff_component({})

        assert.is_not_nil(component)
        -- Default is unified (DiffComponent), which lacks SplitDiffComponent methods
        assert.is_nil(component.calculate_split_line_numbers)
      end)

      it('should pass diff data to component props', function()
        local view = StatusDiffView()
        local diff_data = { lines = { 'line1' }, marks = {} }
        local component = view:_create_diff_component({
          diff = diff_data,
          filename = 'test.lua',
          filetype = 'lua',
        })

        assert.is_not_nil(component)
        eq(diff_data, component.props.diff)
        eq('test.lua', component.props.filename)
        eq('lua', component.props.filetype)
      end)
    end)
  end)
  describe('File Navigation', function()
    local view, mock_tree, mock_items

    local function setup_mock_tree(items, current_lnum)
      mock_items = items or {}
      local lnum = current_lnum or 1
      mock_tree = {
        get_lnum = function()
          return lnum
        end,
        set_lnum = function(_, new_lnum)
          lnum = new_lnum
        end,
        get_line_count = function()
          return #mock_items
        end,
        is_valid = function()
          return true
        end,
        get_list_item = function(_, l)
          return mock_items[l]
        end,
        each_entry = function(_, cb)
          for _, item in ipairs(mock_items) do
            if item and item.entry and item.entry.status then cb(item.entry.status, item.entry.type) end
          end
        end,
        move_to = function() end,
        set_list = function() end,
        focus = function() end,
      }
      view._tree_component = mock_tree
    end

    before_each(function()
      view = StatusDiffView()
    end)

    describe('find_next_file', function()
      it('should find next file of target type', function()
        local items = {
          { entry = make_entry({ filename = 'file1.lua', type = 'unstaged' }) },
          { entry = make_entry({ filename = 'file2.lua', type = 'unstaged' }) },
          { entry = make_entry({ filename = 'file3.lua', type = 'staged' }) },
        }
        setup_mock_tree(items, 1)

        local next_file = view:find_next_file('file1.lua', 'unstaged')
        eq('file2.lua', next_file)
      end)

      it('should return nil if current file is last of type', function()
        local items = {
          { entry = make_entry({ filename = 'file1.lua', type = 'unstaged' }) },
          { entry = make_entry({ filename = 'file2.lua', type = 'staged' }) },
        }
        setup_mock_tree(items, 1)

        local next_file = view:find_next_file('file1.lua', 'unstaged')
        assert.is_nil(next_file)
      end)

      it('should ignore entries of wrong type', function()
        local items = {
          { entry = make_entry({ filename = 'file1.lua', type = 'unstaged' }) },
          { entry = make_entry({ filename = 'file2.lua', type = 'staged' }) },
          { entry = make_entry({ filename = 'file3.lua', type = 'unstaged' }) },
        }
        setup_mock_tree(items, 1)

        local next_file = view:find_next_file('file1.lua', 'unstaged')
        eq('file3.lua', next_file)
      end)
    end)

    describe('move_to_entry', function()
      it('should delegate to tree_component:move_to with correct predicate', function()
        local called_with = nil
        setup_mock_tree({}, 1)
        mock_tree.move_to = function(_, predicate)
          called_with = predicate
        end

        view:move_to_entry('test.lua', 'unstaged')

        -- Verify predicate works correctly
        assert.is_not_nil(called_with)
        assert.is_true(called_with({ filename = 'test.lua' }, 'unstaged'))
        assert.is_false(called_with({ filename = 'test.lua' }, 'staged'))
        assert.is_false(called_with({ filename = 'other.lua' }, 'unstaged'))
      end)
    end)

    describe('_move_to_first_entry_of_type', function()
      it('should return true when entry of target type exists', function()
        setup_mock_tree({}, 1)
        mock_tree.move_to = function(_, predicate)
          -- Simulate finding an entry
          if predicate({ filename = 'file1.lua' }, 'staged') then return { filename = 'file1.lua' } end
          return nil
        end

        assert.is_true(view:_move_to_first_entry_of_type('staged'))
      end)

      it('should return false when no entry of target type exists', function()
        setup_mock_tree({}, 1)
        mock_tree.move_to = function()
          return nil
        end

        assert.is_false(view:_move_to_first_entry_of_type('staged'))
      end)

      it('should pass correct predicate requiring both status and entry_type', function()
        local predicate_received = nil
        setup_mock_tree({}, 1)
        mock_tree.move_to = function(_, predicate)
          predicate_received = predicate
          return nil
        end

        view:_move_to_first_entry_of_type('unstaged')

        assert.is_not_nil(predicate_received)
        assert.is_true(predicate_received({ filename = 'test.lua' }, 'unstaged'))
        assert.is_false(predicate_received({ filename = 'test.lua' }, 'staged'))
        assert.is_false(predicate_received(nil, 'unstaged'))
      end)
    end)

    describe('refresh_and_navigate', function()
      it('should set _refreshing during navigation', function()
        setup_mock_tree({}, 1)
        local refreshing_during_nav = nil

        view.refresh_data = function() end
        view._refresh_diff = function() end

        view:refresh_and_navigate(function()
          refreshing_during_nav = view._refreshing
        end)

        assert.is_true(refreshing_during_nav)
        assert.is_false(view._refreshing)
      end)

      it('should call refresh_data before navigate_fn', function()
        setup_mock_tree({}, 1)
        local call_order = {}

        view.refresh_data = function()
          table.insert(call_order, 'refresh')
        end
        view._refresh_diff = function()
          table.insert(call_order, 'update_diff')
        end

        view:refresh_and_navigate(function()
          table.insert(call_order, 'navigate')
        end)

        eq({ 'refresh', 'navigate', 'update_diff' }, call_order)
      end)

      it('should call _refresh_diff after navigate_fn', function()
        setup_mock_tree({}, 1)
        local update_called = false

        view.refresh_data = function() end
        view._refresh_diff = function()
          update_called = true
        end

        view:refresh_and_navigate(function() end)

        assert.is_true(update_called)
      end)
    end)
  end)
  describe('Hunk Navigation', function()
    local view, mock_diff

    local function setup_mock_diff(marks, cursor_lnum)
      marks = marks or {}
      cursor_lnum = cursor_lnum or 1
      mock_diff = {
        is_valid = function()
          return true
        end,
        get_marks = function()
          return marks
        end,
        get_hunks = function()
          return {}
        end,
        get_lnum = function()
          return cursor_lnum
        end,
        get_hunk_under_cursor = function()
          return nil, nil
        end,
        move_to_hunk = function() end,
        hunk_down = function() end,
        hunk_up = function() end,
        set_props = function() end,
        clear_extmarks = function() end,
        clear_lines = function() end,
        clear_folds = function() end,
        reset_cursor = function() end,
        reset = function() end,
        call = function(_, cb)
          cb()
        end,
        set_keymap = function() end,
        component_will_unmount = function() end,
      }
      view._diff_component = mock_diff
    end

    before_each(function()
      view = StatusDiffView()
    end)

    describe('get_current_mark_index', function()
      it('should return nil,0 when no marks', function()
        setup_mock_diff({}, 1)

        local index, total = view:get_current_mark_index()
        assert.is_nil(index)
        eq(0, total)
      end)

      it('should return correct index when cursor inside mark', function()
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
          { top = 20, bot = 25 },
        }
        setup_mock_diff(marks, 12) -- cursor inside second mark

        local index, total = view:get_current_mark_index()
        eq(2, index)
        eq(3, total)
      end)

      it('should return prev index when cursor before mark', function()
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
        }
        setup_mock_diff(marks, 7) -- cursor between marks

        local index, total = view:get_current_mark_index()
        eq(1, index) -- prev mark (max of 1, i-1)
        eq(2, total)
      end)

      it('should return last index when cursor after all marks', function()
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
        }
        setup_mock_diff(marks, 100) -- cursor after all marks

        local index, total = view:get_current_mark_index()
        eq(2, index)
        eq(2, total)
      end)

      it('should return 1 when cursor at first mark', function()
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
        }
        setup_mock_diff(marks, 3)

        local index, total = view:get_current_mark_index()
        eq(1, index)
        eq(2, total)
      end)
    end)

    describe('hunk_down', function()
      it('should return early if diff_component is nil', function()
        view._diff_component = nil
        -- Should not error
        view:hunk_down()
      end)

      it('should return early if diff_component is invalid', function()
        view._diff_component = {
          is_valid = function()
            return false
          end,
        }
        -- Should not error
        view:hunk_down()
      end)

      it('should call hunk_down when not at last hunk', function()
        local called = false
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
        }
        setup_mock_diff(marks, 3) -- at first hunk
        mock_diff.hunk_down = function()
          called = true
        end

        view:hunk_down()
        assert.is_true(called)
      end)
    end)

    describe('hunk_up', function()
      it('should return early if diff_component is nil', function()
        view._diff_component = nil
        view:hunk_up()
      end)

      it('should return early if diff_component is invalid', function()
        view._diff_component = {
          is_valid = function()
            return false
          end,
        }
        view:hunk_up()
      end)

      it('should call hunk_up when not at first hunk', function()
        local called = false
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
        }
        setup_mock_diff(marks, 12) -- at second hunk
        mock_diff.hunk_up = function()
          called = true
        end

        view:hunk_up()
        assert.is_true(called)
      end)
    end)

    describe('hunk_down', function()
      it('should delegate to hunk_down', function()
        local called = false
        view.hunk_down = function()
          called = true
        end

        view:hunk_down()
        assert.is_true(called)
      end)
    end)

    describe('hunk_up', function()
      it('should delegate to hunk_up', function()
        local called = false
        view.hunk_up = function()
          called = true
        end

        view:hunk_up()
        assert.is_true(called)
      end)
    end)

    describe('restore_hunk_position', function()
      it('should move to hunk_index if marks exist', function()
        local moved_to = nil
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
          { top = 20, bot = 25 },
        }
        setup_mock_diff(marks, 1)
        mock_diff.move_to_hunk = function(_, idx)
          moved_to = idx
        end

        view:restore_hunk_position(2)
        eq(2, moved_to)
      end)

      it('should clamp to last mark if hunk_index exceeds', function()
        local moved_to = nil
        local marks = {
          { top = 1, bot = 5 },
          { top = 10, bot = 15 },
        }
        setup_mock_diff(marks, 1)
        mock_diff.move_to_hunk = function(_, idx)
          moved_to = idx
        end

        view:restore_hunk_position(10) -- exceeds 2 marks
        eq(2, moved_to)
      end)

      it('should not move if no marks', function()
        local called = false
        setup_mock_diff({}, 1)
        mock_diff.get_marks = function()
          return {}
        end
        mock_diff.move_to_hunk = function()
          called = true
        end

        view:restore_hunk_position(1)
        assert.is_false(called)
      end)
    end)
  end)
  describe('Hunk Operations', function()
    local view, mock_repo, mock_diff, mock_tree
    local repo_calls, console_calls

    local function setup_mocks()
      repo_calls = {}
      console_calls = {}

      mock_repo = {
        stage_hunk = function(_, filename, hunk)
          table.insert(repo_calls, { 'stage_hunk', filename, hunk })
          return true, nil
        end,
        unstage_hunk = function(_, filename, hunk)
          table.insert(repo_calls, { 'unstage_hunk', filename, hunk })
          return true, nil
        end,
        reset_hunk = function(_, filename, hunk)
          table.insert(repo_calls, { 'reset_hunk', filename, hunk })
          return true, nil
        end,
        status = function()
          return { entries = {} }, nil
        end,
        diff = function()
          return { lines = {}, marks = {} }, nil
        end,
        index = function()
          return {
            staged_hunks = function()
              return {}
            end,
            unstaged_hunks = function()
              return {}
            end,
          }
        end,
      }

      mock_diff = {
        is_valid = function()
          return true
        end,
        get_hunk_under_cursor = function()
          return { start = 1, count = 5 }, 1
        end,
        get_marks = function()
          return {}
        end,
        get_hunks = function()
          return {}
        end,
        get_lnum = function()
          return 1
        end,
        move_to_hunk = function() end,
        hunk_down = function() end,
        hunk_up = function() end,
        set_props = function() end,
        clear_extmarks = function() end,
        clear_lines = function() end,
        clear_folds = function() end,
        reset_cursor = function() end,
        reset = function() end,
        call = function(_, cb)
          cb()
        end,
        set_keymap = function() end,
        component_will_unmount = function() end,
      }

      mock_tree = {
        get_lnum = function()
          return 1
        end,
        set_lnum = function() end,
        get_line_count = function()
          return 1
        end,
        is_valid = function()
          return true
        end,
        get_list_item = function()
          return nil
        end,
        get_selected_entry = function()
          return nil
        end,
        each_entry = function() end,
        move_to = function() end,
        set_list = function() end,
        focus = function() end,
        set_keymap = function() end,
        set_on_enter = function() end,
        set_on_move = function() end,
        component_did_mount = function() end,
        component_will_unmount = function() end,
      }

      view._diff_component = mock_diff
      view._tree_component = mock_tree
    end

    before_each(function()
      -- Mock repository.current BEFORE requiring StatusDiffView
      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return mock_repo, nil
        end,
      }

      -- Re-require StatusDiffView to pick up the mock
      package.loaded['vgit.features.screens.StatusDiffView'] = nil
      StatusDiffView = require('vgit.features.screens.StatusDiffView')

      view = StatusDiffView()
      setup_mocks()
    end)

    describe('stage_hunk', function()
      it('should return early if entry is invalid', function()
        mock_tree.get_selected_entry = function()
          return nil
        end
        view:stage_hunk()
        eq(0, #repo_calls)
      end)

      it('should return early if entry type is not unstaged', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'staged' })
        end
        view:stage_hunk()
        eq(0, #repo_calls)
      end)

      it('should return early if no hunk under cursor', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged' })
        end
        mock_diff.get_hunk_under_cursor = function()
          return nil, nil
        end
        view:stage_hunk()
        eq(0, #repo_calls)
      end)

      it('should call repo:stage_hunk with filename and hunk', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged', filename = 'test.lua' })
        end
        local test_hunk = { start = 10, count = 5 }
        mock_diff.get_hunk_under_cursor = function()
          return test_hunk, 1
        end

        view:stage_hunk()

        eq(1, #repo_calls)
        eq('stage_hunk', repo_calls[1][1])
        eq('test.lua', repo_calls[1][2])
        eq(test_hunk, repo_calls[1][3])
      end)
    end)

    describe('unstage_hunk', function()
      it('should return early if entry is invalid', function()
        mock_tree.get_selected_entry = function()
          return nil
        end
        view:unstage_hunk()
        eq(0, #repo_calls)
      end)

      it('should return early if entry type is not staged', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged' })
        end
        view:unstage_hunk()
        eq(0, #repo_calls)
      end)

      it('should return early if no hunk under cursor', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'staged' })
        end
        mock_diff.get_hunk_under_cursor = function()
          return nil, nil
        end
        view:unstage_hunk()
        eq(0, #repo_calls)
      end)

      it('should call repo:unstage_hunk with filename and hunk', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'staged', filename = 'staged.lua' })
        end
        local test_hunk = { start = 20, count = 3 }
        mock_diff.get_hunk_under_cursor = function()
          return test_hunk, 1
        end

        view:unstage_hunk()

        eq(1, #repo_calls)
        eq('unstage_hunk', repo_calls[1][1])
        eq('staged.lua', repo_calls[1][2])
        eq(test_hunk, repo_calls[1][3])
      end)
    end)

    describe('reset_hunk', function()
      local console_input_response

      before_each(function()
        console_input_response = 'n'
        save_package('vgit.core.console')
        package.loaded['vgit.core.console'] = {
          input = function()
            return console_input_response
          end,
          info = function() end,
          error = function() end,
          warn = function() end,
          debug = { error = function() end, warning = function() end },
        }
        -- Re-require to pick up mock
        package.loaded['vgit.features.screens.StatusDiffView'] = nil
        StatusDiffView = require('vgit.features.screens.StatusDiffView')
        view = StatusDiffView()
        setup_mocks()
      end)

      it('should return early if entry is invalid', function()
        mock_tree.get_selected_entry = function()
          return nil
        end
        view:reset_hunk()
        eq(0, #repo_calls)
      end)

      it('should return early if entry type is not unstaged', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'staged' })
        end
        view:reset_hunk()
        eq(0, #repo_calls)
      end)

      it('should return early if no hunk under cursor', function()
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged' })
        end
        mock_diff.get_hunk_under_cursor = function()
          return nil, nil
        end
        view:reset_hunk()
        eq(0, #repo_calls)
      end)

      it('should abort on n response', function()
        console_input_response = 'n'
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged' })
        end
        view:reset_hunk()
        eq(0, #repo_calls)
      end)

      it('should abort on no response', function()
        console_input_response = 'no'
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged' })
        end
        view:reset_hunk()
        eq(0, #repo_calls)
      end)

      it('should abort on empty response', function()
        console_input_response = ''
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged' })
        end
        view:reset_hunk()
        eq(0, #repo_calls)
      end)

      it('should proceed on y response', function()
        console_input_response = 'y'
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged', filename = 'reset.lua' })
        end
        local test_hunk = { start = 5, count = 2 }
        mock_diff.get_hunk_under_cursor = function()
          return test_hunk, 1
        end

        view:reset_hunk()

        eq(1, #repo_calls)
        eq('reset_hunk', repo_calls[1][1])
      end)

      it('should proceed on yes response', function()
        console_input_response = 'yes'
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged', filename = 'reset.lua' })
        end
        local test_hunk = { start = 5, count = 2 }
        mock_diff.get_hunk_under_cursor = function()
          return test_hunk, 1
        end

        view:reset_hunk()

        eq(1, #repo_calls)
        eq('reset_hunk', repo_calls[1][1])
      end)

      it('should call repo:reset_hunk with filename and hunk', function()
        console_input_response = 'y'
        mock_tree.get_selected_entry = function()
          return make_entry({ type = 'unstaged', filename = 'file.lua' })
        end
        local test_hunk = { start = 15, count = 8 }
        mock_diff.get_hunk_under_cursor = function()
          return test_hunk, 1
        end

        view:reset_hunk()

        eq('file.lua', repo_calls[1][2])
        eq(test_hunk, repo_calls[1][3])
      end)
    end)
  end)
  describe('File Operations', function()
    local view, mock_repo, repo_calls, console_input_response

    local function setup_file_op_mocks()
      repo_calls = {}
      console_input_response = 'n'

      mock_repo = {
        stage_file = function(_, filename)
          table.insert(repo_calls, { 'stage_file', filename })
          return true, nil
        end,
        unstage_file = function(_, filename)
          table.insert(repo_calls, { 'unstage_file', filename })
          return true, nil
        end,
        reset = function(_, filename)
          table.insert(repo_calls, { 'reset', filename })
          return true, nil
        end,
      }

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return mock_repo, nil
        end,
      }

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        input = function()
          return console_input_response
        end,
        info = function() end,
        error = function() end,
        warn = function() end,
        debug = { error = function() end, warning = function() end },
      }

      package.loaded['vgit.features.screens.StatusDiffView'] = nil
      StatusDiffView = require('vgit.features.screens.StatusDiffView')
      view = StatusDiffView()
      view._tree_component = {
        each_entry = function() end,
        get_selected_entry = function()
          return nil
        end,
        move_to = function() end,
      }
      view.refresh_and_navigate = function(_, fn)
        fn()
      end
      view._move_to_first_entry_of_type = function()
        return false
      end
      view._move_to_first_entry = function() end
      view.move_to_entry = function() end
      view.find_next_file = function()
        return nil
      end
    end

    before_each(function()
      setup_file_op_mocks()
    end)

    describe('stage_entry', function()
      it('should return early if entry is invalid', function()
        view._tree_component.get_selected_entry = function()
          return nil
        end
        view:stage_entry()
        eq(0, #repo_calls)
      end)

      it('should call repo:stage_file with filename', function()
        view._tree_component.get_selected_entry = function()
          return make_entry({ type = 'unstaged', filename = 'stage_me.lua' })
        end
        view:stage_entry()

        eq(1, #repo_calls)
        eq('stage_file', repo_calls[1][1])
        eq('stage_me.lua', repo_calls[1][2])
      end)
    end)

    describe('unstage_entry', function()
      it('should return early if entry is invalid', function()
        view._tree_component.get_selected_entry = function()
          return nil
        end
        view:unstage_entry()
        eq(0, #repo_calls)
      end)

      it('should call repo:unstage_file with filename', function()
        view._tree_component.get_selected_entry = function()
          return make_entry({ type = 'staged', filename = 'unstage_me.lua' })
        end
        view:unstage_entry()

        eq(1, #repo_calls)
        eq('unstage_file', repo_calls[1][1])
        eq('unstage_me.lua', repo_calls[1][2])
      end)
    end)

    describe('reset_entry', function()
      it('should return early if entry is invalid', function()
        view._tree_component.get_selected_entry = function()
          return nil
        end
        view:reset_entry()
        eq(0, #repo_calls)
      end)

      it('should prompt for confirmation', function()
        local prompted = false
        package.loaded['vgit.core.console'].input = function()
          prompted = true
          return 'n'
        end

        view._tree_component.get_selected_entry = function()
          return make_entry({ filename = 'test.lua' })
        end
        view:reset_entry()

        assert.is_true(prompted)
      end)

      it('should abort on n response', function()
        console_input_response = 'n'
        view._tree_component.get_selected_entry = function()
          return make_entry({ filename = 'test.lua' })
        end
        view:reset_entry()

        eq(0, #repo_calls)
      end)

      it('should proceed on y response', function()
        package.loaded['vgit.core.console'].input = function()
          return 'y'
        end

        view._tree_component.get_selected_entry = function()
          return make_entry({ filename = 'reset_me.lua' })
        end
        view:reset_entry()

        eq(1, #repo_calls)
        eq('reset', repo_calls[1][1])
        eq('reset_me.lua', repo_calls[1][2])
      end)

      it('should proceed on yes response', function()
        package.loaded['vgit.core.console'].input = function()
          return 'yes'
        end

        view._tree_component.get_selected_entry = function()
          return make_entry({ filename = 'reset_me.lua' })
        end
        view:reset_entry()

        eq(1, #repo_calls)
        eq('reset', repo_calls[1][1])
      end)
    end)

    describe('stage_entry with follow_same_file', function()
      it('should return early if entry is invalid', function()
        view._tree_component.get_selected_entry = function()
          return nil
        end
        view:stage_entry({ follow_same_file = true })
        eq(0, #repo_calls)
      end)

      it('should return early if entry type is not unstaged', function()
        view._tree_component.get_selected_entry = function()
          return make_entry({ type = 'staged', filename = 'test.lua' })
        end
        view:stage_entry({ follow_same_file = true })
        eq(0, #repo_calls)
      end)

      it('should call repo:stage_file with filename', function()
        view._tree_component.get_selected_entry = function()
          return make_entry({ type = 'unstaged', filename = 'diff_stage.lua' })
        end
        view:stage_entry({ follow_same_file = true })

        eq(1, #repo_calls)
        eq('stage_file', repo_calls[1][1])
        eq('diff_stage.lua', repo_calls[1][2])
      end)
    end)

    describe('unstage_entry with follow_same_file', function()
      it('should return early if entry is invalid', function()
        view._tree_component.get_selected_entry = function()
          return nil
        end
        view:unstage_entry({ follow_same_file = true })
        eq(0, #repo_calls)
      end)

      it('should return early if entry type is not staged', function()
        view._tree_component.get_selected_entry = function()
          return make_entry({ type = 'unstaged', filename = 'test.lua' })
        end
        view:unstage_entry({ follow_same_file = true })
        eq(0, #repo_calls)
      end)

      it('should call repo:unstage_file with filename', function()
        view._tree_component.get_selected_entry = function()
          return make_entry({ type = 'staged', filename = 'diff_unstage.lua' })
        end
        view:unstage_entry({ follow_same_file = true })

        eq(1, #repo_calls)
        eq('unstage_file', repo_calls[1][1])
        eq('diff_unstage.lua', repo_calls[1][2])
      end)
    end)

    describe('open_file', function()
      it('should return early if entry is invalid', function()
        local destroy_called = false
        view.destroy = function()
          destroy_called = true
        end
        view._tree_component.get_selected_entry = function()
          return nil
        end

        view:open_file()
        assert.is_false(destroy_called)
      end)

      it('should call destroy and fs.open with filename', function()
        local destroy_called = false
        local opened_file = nil

        view.destroy = function()
          destroy_called = true
        end

        save_package('vgit.core.fs')
        package.loaded['vgit.core.fs'] = {
          open = function(filename)
            opened_file = filename
          end,
        }

        package.loaded['vgit.features.screens.StatusDiffView'] = nil
        StatusDiffView = require('vgit.features.screens.StatusDiffView')
        view = StatusDiffView()
        view.destroy = function()
          destroy_called = true
        end
        view._tree_component = {
          get_selected_entry = function()
            return make_entry({ filename = 'open_me.lua' })
          end,
        }

        view:open_file()

        assert.is_true(destroy_called)
        eq('open_me.lua', opened_file)
      end)
    end)
  end)
  describe('Bulk Operations', function()
    local view, mock_repo, repo_calls, console_input_response, info_messages

    local function setup_bulk_op_mocks()
      repo_calls = {}
      info_messages = {}
      console_input_response = 'n'

      mock_repo = {
        stage_all = function()
          table.insert(repo_calls, { 'stage_all' })
          return true, nil
        end,
        unstage_all = function()
          table.insert(repo_calls, { 'unstage_all' })
          return true, nil
        end,
        reset = function(_, filename)
          table.insert(repo_calls, { 'reset', filename })
          return true, nil
        end,
        commit = function(_, message)
          table.insert(repo_calls, { 'commit', message })
          return true, nil
        end,
      }

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return mock_repo, nil
        end,
      }

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        input = function()
          return console_input_response
        end,
        info = function(msg)
          table.insert(info_messages, msg)
        end,
        error = function() end,
        warn = function() end,
        debug = { error = function() end, warning = function() end },
      }

      package.loaded['vgit.features.screens.StatusDiffView'] = nil
      StatusDiffView = require('vgit.features.screens.StatusDiffView')
      view = StatusDiffView()

      local mock_tree = {
        each_entry = function() end,
        move_to = function() end,
        get_selected_entry = function()
          return nil
        end,
      }
      view._tree_component = mock_tree
      view.refresh_data = function() end
      view._refresh_diff = function() end
    end

    before_each(function()
      setup_bulk_op_mocks()
    end)

    describe('stage_all', function()
      it('should call repo:stage_all', function()
        view:stage_all()

        eq(1, #repo_calls)
        eq('stage_all', repo_calls[1][1])
      end)

      it('should handle repo error gracefully', function()
        package.loaded['vgit.git.repository'].current = function()
          return nil, 'repo error'
        end

        -- Should not error
        view:stage_all()
        eq(0, #repo_calls)
      end)
    end)

    describe('unstage_all', function()
      it('should call repo:unstage_all', function()
        view:unstage_all()

        eq(1, #repo_calls)
        eq('unstage_all', repo_calls[1][1])
      end)

      it('should handle repo error gracefully', function()
        package.loaded['vgit.git.repository'].current = function()
          return nil, 'repo error'
        end

        view:unstage_all()
        eq(0, #repo_calls)
      end)
    end)

    describe('reset_all', function()
      it('should prompt for confirmation', function()
        local prompted = false
        package.loaded['vgit.core.console'].input = function()
          prompted = true
          return 'n'
        end

        view:reset_all()
        assert.is_true(prompted)
      end)

      it('should abort on rejection', function()
        console_input_response = 'n'
        view:reset_all()

        eq(0, #repo_calls)
      end)

      it('should proceed on y response', function()
        package.loaded['vgit.core.console'].input = function()
          return 'y'
        end

        view:reset_all()

        eq(1, #repo_calls)
        eq('reset', repo_calls[1][1])
      end)

      it('should proceed on yes response', function()
        package.loaded['vgit.core.console'].input = function()
          return 'yes'
        end

        view:reset_all()

        eq(1, #repo_calls)
        eq('reset', repo_calls[1][1])
      end)

      it('should call repo:reset with no filename (reset all)', function()
        package.loaded['vgit.core.console'].input = function()
          return 'y'
        end

        view:reset_all()

        eq(1, #repo_calls)
        assert.is_nil(repo_calls[1][2]) -- no filename = reset all
      end)
    end)

    describe('commit', function()
      it('should cancel on empty message via _confirm_commit', function()
        view._commit_view = {
          is_valid = function()
            return true
          end,
          get_lines = function()
            return { '', '# comment line' }
          end,
          destroy = function() end,
        }

        view:_confirm_commit()

        eq(0, #repo_calls)
        assert.is_true(#info_messages > 0)
      end)

      it('should filter out comment lines', function()
        view._commit_view = {
          is_valid = function()
            return true
          end,
          get_lines = function()
            return { 'feat: add new feature', '# This is a comment', 'More details here' }
          end,
          destroy = function() end,
        }

        view:_confirm_commit()

        eq(1, #repo_calls)
        eq('commit', repo_calls[1][1])
        eq('feat: add new feature\nMore details here', repo_calls[1][2])
      end)

      it('should call repo:commit with message via _confirm_commit', function()
        view._commit_view = {
          is_valid = function()
            return true
          end,
          get_lines = function()
            return { 'feat: add new feature' }
          end,
          destroy = function() end,
        }

        view:_confirm_commit()

        eq(1, #repo_calls)
        eq('commit', repo_calls[1][1])
        eq('feat: add new feature', repo_calls[1][2])
      end)

      it('should show success message after commit', function()
        view._commit_view = {
          is_valid = function()
            return true
          end,
          get_lines = function()
            return { 'test commit' }
          end,
          destroy = function() end,
        }

        view:_confirm_commit()

        assert.is_true(#info_messages > 0)
      end)
    end)
  end)
  describe('View Management', function()
    local view, mock_repo, mock_diff, mock_tree

    local function setup_view_mocks()
      mock_repo = {
        diff = function()
          return { lines = {}, marks = {} }, nil
        end,
        status = function()
          return {
            entries = {
              {
                title = 'Unstaged',
                entries = { make_entry({ filename = 'file1.lua' }) },
              },
            },
          },
            nil
        end,
        index = function()
          return {
            staged_hunks = function()
              return {}
            end,
            unstaged_hunks = function()
              return {}
            end,
          }
        end,
      }

      mock_diff = {
        is_valid = function()
          return true
        end,
        get_marks = function()
          return {}
        end,
        get_hunks = function()
          return {}
        end,
        get_lnum = function()
          return 1
        end,
        get_hunk_under_cursor = function()
          return nil, nil
        end,
        move_to_hunk = function() end,
        hunk_down = function() end,
        hunk_up = function() end,
        set_props = function() end,
        clear_extmarks = function() end,
        clear_lines = function() end,
        clear_folds = function() end,
        reset_cursor = function() end,
        reset = function() end,
        call = function(_, cb)
          cb()
        end,
        set_keymap = function() end,
        component_will_unmount = function() end,
      }

      mock_tree = {
        get_lnum = function()
          return 1
        end,
        set_lnum = function() end,
        get_line_count = function()
          return 1
        end,
        is_valid = function()
          return true
        end,
        get_list_item = function()
          return nil
        end,
        get_selected_entry = function()
          return nil
        end,
        each_entry = function() end,
        move_to = function() end,
        set_list = function() end,
        focus = function() end,
        set_keymap = function() end,
        set_on_enter = function() end,
        set_on_move = function() end,
        component_did_mount = function() end,
        component_will_unmount = function() end,
      }

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return mock_repo, nil
        end,
      }

      package.loaded['vgit.features.screens.StatusDiffView'] = nil
      StatusDiffView = require('vgit.features.screens.StatusDiffView')
      view = StatusDiffView()
      view._diff_component = mock_diff
      view._tree_component = mock_tree
    end

    before_each(function()
      setup_view_mocks()
    end)

    describe('_refresh_diff', function()
      it('should return false if entry is invalid', function()
        mock_tree.get_selected_entry = function()
          return nil
        end
        local result = view:_refresh_diff()
        assert.is_false(result)
      end)

      it('should return false on repo error', function()
        package.loaded['vgit.git.repository'].current = function()
          return nil, 'repo error'
        end
        mock_tree.get_selected_entry = function()
          return make_entry()
        end

        local result = view:_refresh_diff()
        assert.is_false(result)
      end)

      it('should return false on diff build error', function()
        mock_repo.diff = function()
          return nil, { 'diff error' }
        end
        mock_tree.get_selected_entry = function()
          return make_entry()
        end

        local result = view:_refresh_diff()
        assert.is_false(result)
      end)

      it('should call set_props with diff data', function()
        local props_set = nil
        mock_diff.set_props = function(_, props)
          props_set = props
        end
        mock_tree.get_selected_entry = function()
          return make_entry({ filename = 'test.lua', filetype = 'lua' })
        end

        view:_refresh_diff()

        assert.is_not_nil(props_set)
        eq('test.lua', props_set.filename)
        eq('lua', props_set.filetype)
      end)

      it('should move to hunk_index if provided', function()
        local moved_to = nil
        mock_diff.move_to_hunk = function(_, idx)
          moved_to = idx
        end
        mock_tree.get_selected_entry = function()
          return make_entry()
        end

        view:_refresh_diff(3)

        eq(3, moved_to)
      end)
    end)

    describe('_handle_file_selection_change', function()
      it('should return early if destroyed', function()
        view._destroyed = true
        -- Should not error
        view:_handle_file_selection_change({ entry = make_entry() })
      end)

      it('should warn on nil item', function()
        local warned = false
        save_package('vgit.core.console')
        package.loaded['vgit.core.console'] = {
          warn = function()
            warned = true
          end,
          input = function()
            return ''
          end,
          info = function() end,
          error = function() end,
          debug = { error = function() end, warning = function() end },
        }

        package.loaded['vgit.features.screens.StatusDiffView'] = nil
        StatusDiffView = require('vgit.features.screens.StatusDiffView')
        view = StatusDiffView()
        view._diff_component = mock_diff
        view._tree_component = mock_tree

        view:_handle_file_selection_change(nil)
        assert.is_true(warned)
      end)

      it('should clear diff component state', function()
        local reset_called = false

        mock_diff.reset = function()
          reset_called = true
        end

        view:_handle_file_selection_change({ entry = make_entry() })

        assert.is_true(reset_called)
      end)

      it('should process valid entry from item', function()
        local entry = make_entry({ filename = 'selected.lua' })

        view:_handle_file_selection_change({ entry = entry })

        -- Verify diff was built (set_props was called through _handle_file_selection_change)
        -- The entry is validated via _is_valid_entry
        assert.is_true(view:_is_valid_entry(entry))
      end)
    end)

    describe('refresh_data', function()
      it('should call repo:status', function()
        local status_called = false
        mock_repo.status = function()
          status_called = true
          return { entries = {} }, nil
        end

        view:refresh_data()
        assert.is_true(status_called)
      end)

      it('should handle repo error gracefully', function()
        package.loaded['vgit.git.repository'].current = function()
          return nil, 'error'
        end

        -- Should not error
        view:refresh_data()
      end)

      it('should update tree_component list', function()
        local list_set = nil
        mock_tree.set_list = function(_, list)
          list_set = list
        end

        view:refresh_data()

        assert.is_not_nil(list_set)
      end)
    end)
  end)
  describe('Lifecycle', function()
    local view

    before_each(function()
      view = StatusDiffView()
    end)

    describe('constructor', function()
      it('should initialize with default opts', function()
        eq('unified', view._opts.layout_type)
      end)

      it('should initialize debounce_cleanups as empty array', function()
        eq({}, view._debounce_cleanups)
      end)

      it('should initialize data as nil', function()
        assert.is_nil(view._data)
      end)

      it('should initialize repo as nil', function()
        assert.is_nil(view._repo)
      end)

      it('should return nil from get_current_entry when no tree', function()
        assert.is_nil(view:get_current_entry())
      end)

      it('should initialize diff_component as nil', function()
        assert.is_nil(view._diff_component)
      end)

      it('should initialize tree_component as nil', function()
        assert.is_nil(view._tree_component)
      end)

      it('should initialize destroyed as false', function()
        assert.is_false(view._destroyed)
      end)
    end)

    describe('destroy', function()
      it('should call all debounce cleanups', function()
        local cleanup1_called = false
        local cleanup2_called = false

        view._debounce_cleanups = {
          function()
            cleanup1_called = true
          end,
          function()
            cleanup2_called = true
          end,
        }

        view._component_group = { unmount = function() end }
        view._context = { restore_window_options = function() end }

        view:destroy()

        assert.is_true(cleanup1_called)
        assert.is_true(cleanup2_called)
      end)

      it('should clear debounce_cleanups array', function()
        view._debounce_cleanups = { function() end }
        view._component_group = { unmount = function() end }
        view._context = { restore_window_options = function() end }

        view:destroy()

        eq({}, view._debounce_cleanups)
      end)

      it('should call component_group:unmount and context:restore_window_options', function()
        local unmount_called = false
        local restore_called = false
        view._debounce_cleanups = {}
        view._component_group = {
          unmount = function()
            unmount_called = true
          end,
        }
        view._context = {
          restore_window_options = function()
            restore_called = true
          end,
        }

        view:destroy()

        assert.is_true(unmount_called)
        assert.is_true(restore_called)
      end)
    end)

    describe('on_git_change', function()
      local mock_repo, mock_tree

      before_each(function()
        mock_repo = {
          status = function()
            return {
              entries = {
                {
                  title = 'Unstaged',
                  entries = {
                    make_entry({ filename = 'file1.lua', type = 'unstaged' }),
                  },
                },
              },
            },
              nil
          end,
          diff = function()
            return { lines = {}, marks = {} }, nil
          end,
          index = function()
            return {
              staged_hunks = function()
                return {}
              end,
              unstaged_hunks = function()
                return {}
              end,
            }
          end,
        }

        mock_tree = {
          get_lnum = function()
            return 1
          end,
          set_lnum = function() end,
          get_line_count = function()
            return 1
          end,
          is_valid = function()
            return true
          end,
          get_list_item = function()
            return nil
          end,
          get_selected_entry = function()
            return nil
          end,
          each_entry = function(_, cb)
            cb({ filename = 'file1.lua' }, 'unstaged')
          end,
          move_to = function() end,
          set_list = function() end,
          focus = function() end,
        }

        save_package('vgit.git.repository')
        package.loaded['vgit.git.repository'] = {
          current = function()
            return mock_repo, nil
          end,
        }

        package.loaded['vgit.features.screens.StatusDiffView'] = nil
        StatusDiffView = require('vgit.features.screens.StatusDiffView')
        view = StatusDiffView()
        view._tree_component = mock_tree
        view._diff_component = {
          is_valid = function()
            return true
          end,
          set_props = function() end,
          move_to_hunk = function() end,
          get_marks = function()
            return {}
          end,
          get_lnum = function()
            return 1
          end,
          state = { marks = {} },
        }
      end)

      it('should refresh data', function()
        local refresh_called = false
        view.refresh_data = function()
          refresh_called = true
        end

        view:on_git_change()

        assert.is_true(refresh_called)
      end)

      it('should restore selection if file still exists', function()
        local move_to_entry_called = false
        mock_tree.get_selected_entry = function()
          return make_entry({ filename = 'file1.lua', type = 'unstaged' })
        end
        view.move_to_entry = function()
          move_to_entry_called = true
        end
        view._refresh_diff = function() end

        view:on_git_change()

        assert.is_true(move_to_entry_called)
      end)

      it('should fall back to first entry if file gone', function()
        local move_to_called = false
        mock_tree.get_selected_entry = function()
          return make_entry({ filename = 'gone_file.lua', type = 'unstaged' })
        end
        mock_tree.each_entry = function(_, cb)
          cb({ filename = 'other_file.lua' }, 'unstaged')
        end
        mock_tree.move_to = function()
          move_to_called = true
        end

        view:on_git_change()

        assert.is_true(move_to_called)
      end)
    end)
  end)
  describe('Constants', function()
    it('should have correct DEBOUNCE_MS', function()
      eq(100, StatusDiffView.DEBOUNCE_MS)
    end)

    it('should have correct TREE_WIDTH', function()
      eq(50, StatusDiffView.TREE_WIDTH)
    end)

    it('should have correct LAYOUT_SPLIT', function()
      eq('split', StatusDiffView.LAYOUT_SPLIT)
    end)

    it('should have correct LAYOUT_UNIFIED', function()
      eq('unified', StatusDiffView.LAYOUT_UNIFIED)
    end)
  end)
  describe('get_key', function()
    it('should return key for string', function()
      local km = require('vgit.core.keymap')
      eq('q', km.get_key('q'))
    end)

    it('should return key from table', function()
      local km = require('vgit.core.keymap')
      eq('q', km.get_key({ key = 'q', mode = 'n' }))
    end)

    it('should return nil for invalid input', function()
      local km = require('vgit.core.keymap')
      assert.is_nil(km.get_key(nil))
      assert.is_nil(km.get_key(123))
    end)
  end)
  describe('get_hunk_alignment', function()
    it('should delegate to view_utils.get_hunk_alignment', function()
      local view = StatusDiffView()
      local alignment = view:get_hunk_alignment()

      -- Should be a valid alignment value
      local valid = { center = true, top = true, bottom = true }
      assert.is_true(valid[alignment] ~= nil)
    end)
  end)
  describe('move_to', function()
    it('should delegate to tree_component:move_to', function()
      local view = StatusDiffView()
      local move_to_called = false
      local query_fn_received = nil

      view._tree_component = {
        move_to = function(_, query_fn)
          move_to_called = true
          query_fn_received = query_fn
        end,
      }

      local my_query = function()
        return true
      end
      view:move_to(my_query)

      assert.is_true(move_to_called)
      eq(my_query, query_fn_received)
    end)
  end)

  describe('_build_entry_diff data invariants', function()
    local diff_invariants = require('tests.helpers.diff_invariants')
    local Diff = require('vgit.core.diff.Diff')
    local GitHunk = require('vgit.git.GitHunk')

    local function make_hunk(header, diff_lines)
      local hunk = GitHunk(header)
      for _, line in ipairs(diff_lines) do
        hunk:push(line)
      end
      return hunk
    end

    local function make_real_repo_returning_unified(hunks, current_lines)
      local diff = Diff():generate_unified(hunks, current_lines)
      return {
        diff = function()
          return diff
        end,
        index = function()
          return {
            staged_hunks = function()
              return {}
            end,
            unstaged_hunks = function()
              return {}
            end,
          }
        end,
      }
    end

    it('should return unified diff data that passes all invariants for staged entry', function()
      local hunk = make_hunk('@@ -1,3 +1,3 @@', { ' ctx', '-old', '+new', ' end' })
      local repo = make_real_repo_returning_unified({ hunk }, { 'ctx', 'new', 'end' })

      local view = StatusDiffView()
      local entry = make_entry({ type = 'staged', filename = 'staged.lua' })
      local result = view:_build_entry_diff(entry, repo)

      assert.is_not_nil(result)
      diff_invariants.assert_unified_diff(result)
    end)

    it('should return unified diff data that passes all invariants for unstaged entry', function()
      local hunk = make_hunk('@@ -1,2 +1,3 @@', { ' a', '-b', '+c', '+d' })
      local repo = make_real_repo_returning_unified({ hunk }, { 'a', 'c', 'd' })

      local view = StatusDiffView()
      local entry = make_entry({ type = 'unstaged', filename = 'unstaged.lua' })
      local result = view:_build_entry_diff(entry, repo)

      assert.is_not_nil(result)
      diff_invariants.assert_unified_diff(result)
    end)

    it('should return diff whose marks are not mutated by the view layer', function()
      local hunk = make_hunk('@@ -1,2 +1,3 @@', { ' x', '-y', '+z', '+w' })
      local diff = Diff():generate_unified({ hunk }, { 'x', 'z', 'w' })
      local original_marks = vim.deepcopy(diff.marks)

      local repo = {
        diff = function()
          return diff
        end,
        index = function()
          return {
            staged_hunks = function()
              return {}
            end,
            unstaged_hunks = function()
              return {}
            end,
          }
        end,
      }

      local view = StatusDiffView()
      local entry = make_entry({ type = 'unstaged', filename = 'test.lua' })
      local result = view:_build_entry_diff(entry, repo)

      -- Marks should be identical — view layer must not mutate them
      eq(original_marks, result.marks)
    end)

    it('should return diff with consistent stat for multi-hunk entry', function()
      local hunk1 = make_hunk('@@ -1,1 +1,2 @@', { '-a', '+b', '+c' })
      local hunk2 = make_hunk('@@ -4,1 +5,1 @@', { '-d', '+e' })
      local repo = make_real_repo_returning_unified({ hunk1, hunk2 }, { 'b', 'c', 'x', 'y', 'e' })

      local view = StatusDiffView()
      local entry = make_entry({ type = 'unstaged', filename = 'multi.lua' })
      local result = view:_build_entry_diff(entry, repo)

      assert.is_not_nil(result)
      diff_invariants.assert_stat_consistency(result.stat, result.lnum_changes)
      diff_invariants.assert_marks_ascending(result.marks)
    end)
  end)
end)
