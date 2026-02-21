local eq = assert.are.same
local HunkLens = require('vgit.features.lenses.HunkLens')

describe('HunkLens:', function()
  describe('get_key', function()
    local lens

    before_each(function()
      lens = HunkLens()
    end)

    it('should return key as-is for string input', function()
      eq('q', lens:get_key('q'))
      eq('<esc>', lens:get_key('<esc>'))
    end)

    it('should return key from table input', function()
      eq('q', lens:get_key({ key = 'q', desc = 'quit' }))
      eq('j', lens:get_key({ key = 'j', desc = 'down' }))
    end)

    it('should return nil for other types', function()
      assert.is_nil(lens:get_key(123))
      assert.is_nil(lens:get_key(function() end))
    end)
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
    local original_packages = {}

    local function save_package(name)
      original_packages[name] = package.loaded[name]
    end

    before_each(function()
      lens = HunkLens()

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        error = function() end,
        info = function() end,
      }
    end)

    after_each(function()
      for name, module in pairs(original_packages) do
        package.loaded[name] = module
      end
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
end)
