local eq = assert.are.same

-- Mock the event module to avoid async issues in tests
local mock_event = {
  await = function() end,
  async = function(fn) return fn end,
  debounce = function(fn) return fn, function() end end,
  debounce_async = function(fn) return fn, function() end end,
  on = function() end,
  emit = function() end,
  custom_on = function() return function() end end,
  buffer_on = function() end,
  promisify = function(fn) return fn end,
  group = 'VGitGroup',
  register_module = function() end,
}

package.loaded['vgit.core.event'] = mock_event

describe('FileDiffView:', function()
  local FileDiffView
  local original_packages = {}

  local function save_package(name)
    original_packages[name] = package.loaded[name]
  end

  local function restore_packages()
    for name, module in pairs(original_packages) do
      package.loaded[name] = module
    end
    original_packages = {}
  end

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

  -- ==========================================================================
  -- STATE SYNC (mocked view)
  -- ==========================================================================
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
        is_valid = function() return true end,
        move_to_hunk = function() end,
        hunk_up = function() end,
        hunk_down = function() end,
        set_props = function() end,
        set_keymap = function() end,
        get_hunk_under_cursor = function() return nil, nil end,
        component_will_unmount = function() end,
      }

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function() return mock_repo, nil end,
      }

      save_package('vgit.core.fs')
      package.loaded['vgit.core.fs'] = {
        detect_filetype = function(filename) return 'lua' end,
        open = function() end,
      }

      save_package('vgit.features.screens.view_utils')
      package.loaded['vgit.features.screens.view_utils'] = {
        handle_git_error = function(err) return err == nil end,
        get_hunk_alignment = function() return 'top' end,
        get_key = function(keymap) return keymap end,
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

    describe('_reconcile', function()
      it('should return false when diff_component is nil', function()
        view._diff_component = nil
        local result = view:_reconcile()
        assert.is_false(result)
      end)

      it('should return false when diff_component is invalid', function()
        mock_diff.is_valid = function() return false end
        local result = view:_reconcile()
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
        mock_diff.set_props = function(_, props) props_set = props end

        view:_reconcile()

        assert.is_true(refresh_called)
        assert.is_not_nil(props_set)
        eq('test.lua', props_set.filename)
        eq('lua', props_set.filetype)
      end)

      it('should return false when _refresh_diff_data returns nil', function()
        view._refresh_diff_data = function() return nil end
        local result = view:_reconcile()
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
        mock_diff.move_to_hunk = function(_, idx) moved_to = idx end

        view:_reconcile({ hunk_index = 3 })

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
        mock_diff.move_to_hunk = function() move_called = true end

        view:_reconcile()

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

        local result = view:_reconcile()
        assert.is_true(result)
      end)
    end)

    describe('toggle_view', function()
      it('should call _reconcile with hunk_index 1', function()
        local reconcile_opts = nil
        view._reconcile = function(_, opts)
          reconcile_opts = opts
          return true
        end
        view._opts.is_staged = false

        view:toggle_view()

        assert.is_not_nil(reconcile_opts)
        eq(1, reconcile_opts.hunk_index)
      end)

      it('should revert is_staged on failure', function()
        view._reconcile = function() return false end
        view._opts.is_staged = false

        view:toggle_view()

        assert.is_false(view._opts.is_staged)
      end)

      it('should keep is_staged flipped on success', function()
        view._reconcile = function() return true end
        view._opts.is_staged = false

        view:toggle_view()

        assert.is_true(view._opts.is_staged)
      end)

      it('should not call _reconcile when filename is nil', function()
        local reconcile_called = false
        view._reconcile = function() reconcile_called = true; return true end
        view._opts.filename = nil

        view:toggle_view()

        assert.is_false(reconcile_called)
      end)
    end)

    describe('reset_current', function()
      it('should call _reconcile after repo:reset', function()
        local reset_called = false
        local reconcile_called = false

        mock_repo.reset = function() reset_called = true end
        view._reconcile = function() reconcile_called = true; return true end

        save_package('vgit.core.console')
        package.loaded['vgit.core.console'] = {
          input = function() return 'y' end,
          error = function() end,
          warn = function() end,
        }

        package.loaded['vgit.features.screens.FileDiffView'] = nil
        FileDiffView = require('vgit.features.screens.FileDiffView')
        view = FileDiffView()
        view._diff_component = mock_diff
        view._opts.filename = 'test.lua'
        view._opts.is_staged = false
        mock_repo.reset = function() reset_called = true end
        view._reconcile = function() reconcile_called = true; return true end

        view:reset_current()

        assert.is_true(reset_called)
        assert.is_true(reconcile_called)
      end)

      it('should not call _reconcile when is_staged', function()
        local reconcile_called = false
        view._reconcile = function() reconcile_called = true; return true end
        view._opts.is_staged = true

        view:reset_current()

        assert.is_false(reconcile_called)
      end)
    end)
  end)

end)
