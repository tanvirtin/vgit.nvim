local eq = assert.are.same
local HunkLensView = require('vgit.features.lenses.HunkLensView')

describe('HunkLensView:', function()
  require('tests.helpers.get_key_tests')({ describe = describe, it = it, assert = assert }, function()
    return HunkLensView()
  end)

  describe('create_diff_component', function()
    local view

    before_each(function()
      view = HunkLensView()
    end)

    it('should have _create_diff_component method', function()
      assert.is_function(view._create_diff_component)
    end)
  end)

  describe('create validation', function()
    local view
    local save_package, restore_packages = require('tests.helpers.package_mock').create()

    before_each(function()
      view = HunkLensView()

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
      local result = view:create(nil)
      eq(false, result)
    end)

    it('should return false if no diff in data', function()
      local result = view:create({})
      eq(false, result)
    end)

    it('should return false if diff has no marks', function()
      local result = view:create({ diff = {} })
      eq(false, result)
    end)

    it('should return false if marks array is empty', function()
      local result = view:create({ diff = { marks = {} } })
      eq(false, result)
    end)

    it('should return false if target_hunk_index is 0', function()
      local result = view:create({ diff = { marks = { {} } }, target_hunk_index = 0 })
      eq(false, result)
    end)

    it('should return false if target_hunk_index is nil', function()
      local result = view:create({ diff = { marks = { {} } }, target_hunk_index = nil })
      eq(false, result)
    end)
  end)

  describe('constructor', function()
    it('should initialize fields correctly', function()
      local view = HunkLensView()
      assert.is_nil(view._diff_component)
      assert.is_false(view._destroyed)
    end)
  end)

  describe('destroy', function()
    it('should set destroyed flag', function()
      local view = HunkLensView()
      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should be idempotent', function()
      local view = HunkLensView()
      view:destroy()
      assert.has_no.errors(function()
        view:destroy()
      end)
    end)
  end)
end)
