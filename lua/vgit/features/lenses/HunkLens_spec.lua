local eq = assert.are.same
local HunkLens = require('vgit.features.lenses.HunkLens')

describe('HunkLens:', function()
  require('tests.helpers.get_key_tests')({ describe = describe, it = it, assert = assert }, function()
    return HunkLens()
  end)

  describe('create_diff_component', function()
    local lens

    before_each(function()
      lens = HunkLens()
    end)

    it('should have create_diff_component method', function()
      assert.is_function(lens.create_diff_component)
    end)
  end)

  describe('hide', function()
    local lens

    before_each(function()
      lens = HunkLens()
    end)

    it('should return early if not active', function()
      lens.active = false
      local result = lens:hide()
      assert.is_nil(result)
    end)

    it('should set active to false after hiding', function()
      lens.active = true
      lens.component_manager = {
        destroy = function() end,
      }
      lens.diff_component = {
        component_will_unmount = function() end,
      }
      lens:hide()
      eq(false, lens.active)
    end)
  end)

  describe('create validation', function()
    local lens
    local save_package, restore_packages = require('tests.helpers.package_mock').create()

    before_each(function()
      lens = HunkLens()

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        error = function() end,
        info = function() end,
      }
    end)

    after_each(function()
      restore_packages()
    end)

    it('should return false if no data provided', function()
      local result = lens:create(nil)
      eq(false, result)
    end)

    it('should return false if no diff in data', function()
      local result = lens:create({})
      eq(false, result)
    end)

    it('should return false if diff has no marks', function()
      local result = lens:create({ diff = {} })
      eq(false, result)
    end)

    it('should return false if marks array is empty', function()
      local result = lens:create({ diff = { marks = {} } })
      eq(false, result)
    end)

    it('should return false if target_hunk_index is 0', function()
      local result = lens:create({ diff = { marks = { {} } }, target_hunk_index = 0 })
      eq(false, result)
    end)

    it('should return false if target_hunk_index is nil', function()
      local result = lens:create({ diff = { marks = { {} } }, target_hunk_index = nil })
      eq(false, result)
    end)
  end)

  describe('constructor', function()
    it('should initialize all fields correctly', function()
      local lens = HunkLens()
      assert.is_false(lens.active)
      assert.is_nil(lens.diff_component)
      assert.is_nil(lens.component_manager)
    end)
  end)

  describe('emit_cleanup_events', function()
    it('should call component_will_unmount on diff_component', function()
      local lens = HunkLens()
      local unmount_called = false
      lens.diff_component = {
        component_will_unmount = function()
          unmount_called = true
        end,
      }

      lens:emit_cleanup_events()

      assert.is_true(unmount_called)
    end)
  end)

  describe('destroy', function()
    it('should call hide', function()
      local lens = HunkLens()
      lens.active = true
      local cm_destroyed = false
      local unmount_called = false
      lens.component_manager = {
        destroy = function()
          cm_destroyed = true
        end,
      }
      lens.diff_component = {
        component_will_unmount = function()
          unmount_called = true
        end,
      }

      lens:destroy()

      assert.is_true(cm_destroyed)
      assert.is_true(unmount_called)
      assert.is_false(lens.active)
    end)

    it('should do nothing when not active', function()
      local lens = HunkLens()
      lens.active = false

      -- Should not error
      lens:destroy()
    end)
  end)
end)
