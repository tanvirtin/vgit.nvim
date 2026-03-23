local eq = assert.are.same
local mock_event = require('tests.helpers.mock_event').install()

describe('FileDiffView:', function()
  local FileDiffView
  local save_package, restore_packages = require('tests.helpers.package_mock').create()

  before_each(function()
    package.loaded['vgit.features.screens.FileDiffView'] = nil
    FileDiffView = require('vgit.features.screens.FileDiffView')
  end)

  after_each(function()
    restore_packages()
    package.loaded['vgit.core.event'] = mock_event
  end)

  describe('create() validation', function()
    it('should reject nil data', function()
      local view = FileDiffView()
      local result = view:create(nil)
      assert.is_false(result)
    end)

    it('should reject non-table data', function()
      local view = FileDiffView()
      local result = view:create('not a table')
      assert.is_false(result)
    end)

    it('should reject data without diff', function()
      local view = FileDiffView()
      local result = view:create({
        filename = 'test.lua',
      })
      assert.is_false(result)
    end)

    it('should reject data with empty diff', function()
      local view = FileDiffView()
      local result = view:create({
        diff = {},
        filename = 'test.lua',
      })
      assert.is_false(result)
    end)

    it('should reject data without filename', function()
      local view = FileDiffView()
      local result = view:create({
        diff = { lines = { 'a' }, hunks = {}, marks = {} },
      })
      assert.is_false(result)
    end)

    it('should reject data with whitespace-only filename', function()
      local view = FileDiffView()
      local result = view:create({
        diff = { lines = { 'a' }, hunks = {}, marks = {} },
        filename = '   ',
      })
      assert.is_false(result)
    end)

    it('should reject data with non-string filetype', function()
      local view = FileDiffView()
      local result = view:create({
        diff = { lines = { 'a' }, hunks = {}, marks = {} },
        filename = 'test.lua',
        filetype = 123,
      })
      assert.is_false(result)
    end)
  end)
  describe('State Sync', function()
    local view, mock_diff, mock_repo

    local function setup_view_mocks()
      mock_repo = {
        diff = function()
          return { lines = { 'line1' }, hunks = { {} }, marks = { {} } }
        end,
        reset = function() end,
        stage_hunk = function() end,
        unstage_hunk = function() end,
        stage_file = function() end,
        unstage_file = function() end,
      }

      mock_diff = {
        is_valid = function()
          return true
        end,
        move_to_hunk = function() end,
        hunk_up = function() end,
        hunk_down = function() end,
        set_props = function() end,
        set_keymap = function() end,
        get_hunk_under_cursor = function()
          return nil, nil
        end,
        component_will_unmount = function() end,
      }

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return mock_repo, nil
        end,
      }

      save_package('vgit.core.fs')
      package.loaded['vgit.core.fs'] = {
        detect_filetype = function(filename)
          return 'lua'
        end,
        open = function() end,
      }

      save_package('vgit.features.screens.view_utils')
      package.loaded['vgit.features.screens.view_utils'] = {
        handle_git_error = function(err)
          return err == nil
        end,
        get_hunk_alignment = function()
          return 'top'
        end,
        get_key = function(keymap)
          return keymap
        end,
      }

      save_package('vgit.settings.file_diff_view')
      package.loaded['vgit.settings.file_diff_view'] = {
        get = function(_, key)
          if key == 'hunk_alignment' then return '' end
          if key == 'keymaps' then return {} end
          return nil
        end,
      }

      save_package('vgit.settings.scene')
      package.loaded['vgit.settings.scene'] = {
        get = function(_, key)
          if key == 'diff_preference' then return 'unified' end
          return nil
        end,
      }

      package.loaded['vgit.features.screens.FileDiffView'] = nil
      FileDiffView = require('vgit.features.screens.FileDiffView')
      view = FileDiffView()
      view._diff_component = mock_diff
      view._opts.filename = 'test.lua'
    end

    before_each(function()
      setup_view_mocks()
    end)

    describe('_refresh_diff', function()
      it('should return false when diff_component is nil', function()
        view._diff_component = nil
        local result = view:_refresh_diff()
        assert.is_false(result)
      end)

      it('should return false when diff_component is invalid', function()
        mock_diff.is_valid = function()
          return false
        end
        local result = view:_refresh_diff()
        assert.is_false(result)
      end)

      it('should call _refresh_diff_data and set_props', function()
        local refresh_called = false
        local props_set = nil

        view._refresh_diff_data = function()
          refresh_called = true
          return {
            diff = { lines = { 'a' }, hunks = {}, marks = {} },
            filename = 'test.lua',
            filetype = 'lua',
          }
        end
        mock_diff.set_props = function(_, props)
          props_set = props
        end

        view:_refresh_diff()

        assert.is_true(refresh_called)
        assert.is_not_nil(props_set)
        eq('test.lua', props_set.filename)
        eq('lua', props_set.filetype)
      end)

      it('should return false when _refresh_diff_data returns nil', function()
        view._refresh_diff_data = function()
          return nil
        end
        local result = view:_refresh_diff()
        assert.is_false(result)
      end)

      it('should move to hunk_index when provided', function()
        local moved_to = nil
        view._refresh_diff_data = function()
          return {
            diff = { lines = { 'a' }, hunks = {}, marks = {} },
            filename = 'test.lua',
            filetype = 'lua',
          }
        end
        mock_diff.move_to_hunk = function(_, idx)
          moved_to = idx
        end

        view:_refresh_diff({ hunk_index = 3 })

        eq(3, moved_to)
      end)

      it('should not move to hunk when hunk_index is nil', function()
        local move_called = false
        view._refresh_diff_data = function()
          return {
            diff = { lines = { 'a' }, hunks = {}, marks = {} },
            filename = 'test.lua',
            filetype = 'lua',
          }
        end
        mock_diff.move_to_hunk = function()
          move_called = true
        end

        view:_refresh_diff()

        assert.is_false(move_called)
      end)

      it('should return true on success', function()
        view._refresh_diff_data = function()
          return {
            diff = { lines = { 'a' }, hunks = {}, marks = {} },
            filename = 'test.lua',
            filetype = 'lua',
          }
        end

        local result = view:_refresh_diff()
        assert.is_true(result)
      end)
    end)

    describe('toggle_view', function()
      it('should call _refresh_diff with hunk_index 1', function()
        local reconcile_opts = nil
        view._refresh_diff = function(_, opts)
          reconcile_opts = opts
          return true
        end
        view._opts.is_staged = false

        view:toggle_view()

        assert.is_not_nil(reconcile_opts)
        eq(1, reconcile_opts.hunk_index)
      end)

      it('should revert is_staged on failure', function()
        view._refresh_diff = function()
          return false
        end
        view._opts.is_staged = false

        view:toggle_view()

        assert.is_false(view._opts.is_staged)
      end)

      it('should keep is_staged flipped on success', function()
        view._refresh_diff = function()
          return true
        end
        view._opts.is_staged = false

        view:toggle_view()

        assert.is_true(view._opts.is_staged)
      end)

      it('should not call _refresh_diff when filename is nil', function()
        local reconcile_called = false
        view._refresh_diff = function()
          reconcile_called = true
          return true
        end
        view._opts.filename = nil

        view:toggle_view()

        assert.is_false(reconcile_called)
      end)
    end)

    describe('reset_current', function()
      it('should call _refresh_diff after repo:reset', function()
        local reset_called = false
        local reconcile_called = false

        mock_repo.reset = function()
          reset_called = true
        end
        view._refresh_diff = function()
          reconcile_called = true
          return true
        end

        save_package('vgit.core.console')
        package.loaded['vgit.core.console'] = {
          input = function()
            return 'y'
          end,
          error = function() end,
          warn = function() end,
        }

        package.loaded['vgit.features.screens.FileDiffView'] = nil
        FileDiffView = require('vgit.features.screens.FileDiffView')
        view = FileDiffView()
        view._diff_component = mock_diff
        view._opts.filename = 'test.lua'
        view._opts.is_staged = false
        mock_repo.reset = function()
          reset_called = true
        end
        view._refresh_diff = function()
          reconcile_called = true
          return true
        end

        view:reset_current()

        assert.is_true(reset_called)
        assert.is_true(reconcile_called)
      end)

      it('should not call _refresh_diff when is_staged', function()
        local reconcile_called = false
        view._refresh_diff = function()
          reconcile_called = true
          return true
        end
        view._opts.is_staged = true

        view:reset_current()

        assert.is_false(reconcile_called)
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
        get_lnum = function()
          return cursor_lnum
        end,
        hunk_down = function() end,
        hunk_up = function() end,
        move_to_hunk = function() end,
        set_props = function() end,
        set_keymap = function() end,
        component_will_unmount = function() end,
      }

      save_package('vgit.settings.file_diff_view')
      package.loaded['vgit.settings.file_diff_view'] = {
        get = function(_, key)
          if key == 'hunk_alignment' then return 'top' end
          if key == 'hunk_alignment_offset' then return 2 end
          if key == 'keymaps' then return {} end
          return nil
        end,
      }

      package.loaded['vgit.features.screens.FileDiffView'] = nil
      FileDiffView = require('vgit.features.screens.FileDiffView')
      view = FileDiffView()
      view._diff_component = mock_diff
      view._opts.filename = 'test.lua'
    end

    describe('get_current_mark_index', function()
      it('should return nil,0 when no marks', function()
        setup_mock_diff({}, 1)
        local index, total = view:get_current_mark_index()
        assert.is_nil(index)
        eq(0, total)
      end)

      it('should return correct index when cursor inside a mark', function()
        local marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 }, { top = 20, bot = 25 } }
        setup_mock_diff(marks, 12) -- inside second mark
        local index, total = view:get_current_mark_index()
        eq(2, index)
        eq(3, total)
      end)

      it('should return previous index when cursor between marks', function()
        local marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        setup_mock_diff(marks, 7) -- between marks
        local index, total = view:get_current_mark_index()
        eq(1, index)
        eq(2, total)
      end)

      it('should return last index when cursor after all marks', function()
        local marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        setup_mock_diff(marks, 50) -- after all marks
        local index, total = view:get_current_mark_index()
        eq(2, index)
        eq(2, total)
      end)

      it('should return 1 when cursor before first mark', function()
        local marks = { { top = 10, bot = 15 } }
        setup_mock_diff(marks, 1)
        local index, total = view:get_current_mark_index()
        eq(1, index)
        eq(1, total)
      end)

      it('should return correct index at mark boundary (top)', function()
        local marks = { { top = 5, bot = 10 } }
        setup_mock_diff(marks, 5) -- exactly at top
        local index, total = view:get_current_mark_index()
        eq(1, index)
        eq(1, total)
      end)

      it('should return correct index at mark boundary (bot)', function()
        local marks = { { top = 5, bot = 10 } }
        setup_mock_diff(marks, 10) -- exactly at bot
        local index, total = view:get_current_mark_index()
        eq(1, index)
        eq(1, total)
      end)
    end)

    describe('hunk_down', function()
      it('should return early if diff_component is nil', function()
        setup_mock_diff({}, 1)
        view._diff_component = nil
        view:hunk_down() -- should not error
      end)

      it('should return early if diff_component is invalid', function()
        setup_mock_diff({}, 1)
        mock_diff.is_valid = function()
          return false
        end
        view:hunk_down() -- should not error
      end)

      it('should delegate to diff_component:hunk_down with alignment settings', function()
        local called_with = nil
        local marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        setup_mock_diff(marks, 3)
        mock_diff.hunk_down = function(_, pos, offset)
          called_with = { pos, offset }
        end

        view:hunk_down()

        assert.is_not_nil(called_with)
        eq('top', called_with[1])
        eq(2, called_with[2])
      end)

      it('should update statusline after navigation', function()
        local statusline_mod = require('vgit.core.statusline_state')
        local set_hunk_called_with = nil
        local original = statusline_mod.set_hunk
        statusline_mod.set_hunk = function(hunk)
          set_hunk_called_with = hunk
        end

        local marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        setup_mock_diff(marks, 3)

        view:hunk_down()

        assert.is_not_nil(set_hunk_called_with)
        eq(1, set_hunk_called_with.index)
        eq(2, set_hunk_called_with.count)

        statusline_mod.set_hunk = original
      end)
    end)

    describe('hunk_up', function()
      it('should return early if diff_component is nil', function()
        setup_mock_diff({}, 1)
        view._diff_component = nil
        view:hunk_up() -- should not error
      end)

      it('should return early if diff_component is invalid', function()
        setup_mock_diff({}, 1)
        mock_diff.is_valid = function()
          return false
        end
        view:hunk_up() -- should not error
      end)

      it('should delegate to diff_component:hunk_up with alignment settings', function()
        local called_with = nil
        local marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        setup_mock_diff(marks, 12)
        mock_diff.hunk_up = function(_, pos, offset)
          called_with = { pos, offset }
        end

        view:hunk_up()

        assert.is_not_nil(called_with)
        eq('top', called_with[1])
        eq(2, called_with[2])
      end)

      it('should update statusline after navigation', function()
        local statusline_mod = require('vgit.core.statusline_state')
        local set_hunk_called_with = nil
        local original = statusline_mod.set_hunk
        statusline_mod.set_hunk = function(hunk)
          set_hunk_called_with = hunk
        end

        local marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
        setup_mock_diff(marks, 12)

        view:hunk_up()

        assert.is_not_nil(set_hunk_called_with)
        eq(2, set_hunk_called_with.index)
        eq(2, set_hunk_called_with.count)

        statusline_mod.set_hunk = original
      end)
    end)
  end)

  describe('diff data consistency', function()
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

    it('should accept unified diff data that passes all invariants', function()
      local hunk = make_hunk('@@ -1,3 +1,4 @@', { ' a', '-b', '+c', '+d', ' e' })
      local diff = Diff():generate_unified({ hunk }, { 'a', 'c', 'd', 'e' })

      diff_invariants.assert_unified_diff(diff)

      -- Verify the diff has the shape FileDiffView:create expects
      assert.is_truthy(diff.lines)
      assert.is_truthy(diff.marks)
      assert.is_truthy(diff.hunks)
      assert.is_true(#diff.lines > 0)
      assert.is_true(#diff.marks > 0)
    end)

    it('should accept split diff data that passes all invariants', function()
      local hunk = make_hunk('@@ -1,1 +1,2 @@', { '-old', '+new', '+added' })
      local diff = Diff():generate_split({ hunk }, { 'new', 'added' })

      diff_invariants.assert_split_diff(diff)

      -- Verify the split structure FileDiffView uses
      assert.is_truthy(diff.current_lines)
      assert.is_truthy(diff.previous_lines)
      eq(#diff.current_lines, #diff.previous_lines)
    end)

    it('should produce valid unified diff for multi-hunk scenario', function()
      local hunk1 = make_hunk('@@ -1,2 +1,3 @@', { ' a', '-b', '+c', '+d' })
      local hunk2 = make_hunk('@@ -5,2 +6,2 @@', { ' e', '-f', '+g' })
      local diff = Diff():generate_unified({ hunk1, hunk2 }, { 'a', 'c', 'd', 'x', 'y', 'e', 'g' })

      diff_invariants.assert_unified_diff(diff)
      assert.is_true(#diff.marks >= 2)
    end)

    it('should produce valid unified diff for all-add (new file) scenario', function()
      local hunk = make_hunk('@@ -0,0 +1,3 @@', { '+line1', '+line2', '+line3' })
      local diff = Diff():generate_unified({ hunk }, { 'line1', 'line2', 'line3' })

      diff_invariants.assert_unified_diff(diff)

      local add_count = 0
      for _, lc in ipairs(diff.lnum_changes) do
        if lc.type == 'add' then add_count = add_count + 1 end
      end
      eq(3, add_count)
    end)
  end)
end)
