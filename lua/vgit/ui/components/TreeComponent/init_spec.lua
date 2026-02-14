local eq = assert.are.same

-- Mock the event module
package.loaded['vgit.core.event'] = {
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

describe('TreeComponent:', function()
  local TreeComponent

  before_each(function()
    package.loaded['vgit.ui.components.TreeComponent'] = nil
    TreeComponent = require('vgit.ui.components.TreeComponent')
  end)

  describe('constructor', function()
    it('should initialize _rendering as false', function()
      local tc = TreeComponent({ list = {}, title = '' })
      assert.is_false(tc._rendering)
    end)
  end)

  describe('get_selected_entry', function()
    it('should return nil when no element', function()
      local tc = TreeComponent({ list = {}, title = '' })
      assert.is_nil(tc:get_selected_entry())
    end)

    it('should return entry from current list item', function()
      local tc = TreeComponent({ list = {}, title = '' })
      local expected_entry = { type = 'unstaged', status = { filename = 'test.lua' } }
      -- Override get_current_list_item to return a mock item
      tc.get_current_list_item = function() return { entry = expected_entry, value = 'test.lua' } end

      eq(expected_entry, tc:get_selected_entry())
    end)

    it('should return nil when current list item is a folder (no entry)', function()
      local tc = TreeComponent({ list = {}, title = '' })
      tc.get_current_list_item = function() return { value = 'src', items = {} } end

      assert.is_nil(tc:get_selected_entry())
    end)

    it('should return nil when get_current_list_item returns nil', function()
      local tc = TreeComponent({ list = {}, title = '' })
      tc.get_current_list_item = function() return nil end

      assert.is_nil(tc:get_selected_entry())
    end)
  end)
end)
