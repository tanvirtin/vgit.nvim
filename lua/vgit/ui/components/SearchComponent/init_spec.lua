local eq = assert.are.same

-- Mock the event module
package.loaded['vgit.core.event'] = {
  await = function() end,
  async = function(fn)
    return fn
  end,
  debounce = function(fn)
    return fn, function() end
  end,
  debounce_async = function(fn)
    return fn, function() end
  end,
  on = function() end,
  emit = function() end,
  custom_on = function()
    return function() end
  end,
  buffer_on = function() end,
  promisify = function(fn)
    return fn
  end,
  group = 'VGitGroup',
  register_module = function() end,
}

describe('SearchComponent:', function()
  local SearchComponent

  before_each(function()
    package.loaded['vgit.ui.components.SearchComponent'] = nil
    package.loaded['vgit.ui.components.SearchComponent.SearchFilter'] = nil
    SearchComponent = require('vgit.ui.components.SearchComponent')
  end)

  describe('constructor', function()
    it('should initialize state with defaults', function()
      local sc = SearchComponent({
        items = { { label = 'a' } },
        on_select = function() end,
      })
      eq('', sc.state.query)
      eq({}, sc.state.filtered_items)
      eq(1, sc.state.selected_index)
    end)

    it('should store props', function()
      local items = { { label = 'main' }, { label = 'develop' } }
      local on_select = function() end
      local sc = SearchComponent({
        items = items,
        on_select = on_select,
      })
      eq(items, sc.props.items)
      eq(on_select, sc.props.on_select)
    end)

    it('should initialize internal fields', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })
      assert.is_nil(sc._input_element)
      assert.is_nil(sc._list_element)
      assert.is_not_nil(sc._filter)
    end)
  end)

  describe('_apply_filter', function()
    it('should filter items by query and reset selected_index', function()
      local sc = SearchComponent({
        items = {
          { label = 'main' },
          { label = 'develop' },
          { label = 'feature/auth' },
        },
        on_select = function() end,
      })

      sc.state.query = 'main'
      sc:_apply_filter()

      eq(1, #sc.state.filtered_items)
      eq('main', sc.state.filtered_items[1].label)
      eq(1, sc.state.selected_index)
    end)

    it('should return all items when query is empty', function()
      local items = {
        { label = 'main' },
        { label = 'develop' },
      }
      local sc = SearchComponent({
        items = items,
        on_select = function() end,
      })

      sc.state.query = ''
      sc:_apply_filter()

      eq(2, #sc.state.filtered_items)
    end)

    it('should reset selected_index to 1 after filtering', function()
      local sc = SearchComponent({
        items = {
          { label = 'main' },
          { label = 'develop' },
          { label = 'feature' },
        },
        on_select = function() end,
      })

      sc.state.selected_index = 3
      sc.state.query = 'dev'
      sc:_apply_filter()

      eq(1, sc.state.selected_index)
    end)

    it('should use custom on_search when provided', function()
      local custom_called = false
      local custom_query = nil
      local custom_items = nil

      local sc = SearchComponent({
        items = {
          { label = 'main' },
          { label = 'develop' },
        },
        on_select = function() end,
        on_search = function(query, items)
          custom_called = true
          custom_query = query
          custom_items = items
          return { items[1] }
        end,
      })

      sc.state.query = 'test'
      sc:_apply_filter()

      assert.is_true(custom_called)
      eq('test', custom_query)
      eq(2, #custom_items)
      eq(1, #sc.state.filtered_items)
    end)

    it('should handle nil return from on_search', function()
      local sc = SearchComponent({
        items = { { label = 'main' } },
        on_select = function() end,
        on_search = function()
          return nil
        end,
      })

      sc.state.query = 'test'
      sc:_apply_filter()

      eq({}, sc.state.filtered_items)
    end)
  end)

  describe('move', function()
    it('should increment selected_index on move down', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.state.filtered_items = {
        { label = 'a' },
        { label = 'b' },
        { label = 'c' },
      }
      sc.state.selected_index = 1

      sc:move('down')
      eq(2, sc.state.selected_index)
    end)

    it('should decrement selected_index on move up', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.state.filtered_items = {
        { label = 'a' },
        { label = 'b' },
        { label = 'c' },
      }
      sc.state.selected_index = 2

      sc:move('up')
      eq(1, sc.state.selected_index)
    end)

    it('should wrap to first item when moving down past last', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.state.filtered_items = {
        { label = 'a' },
        { label = 'b' },
        { label = 'c' },
      }
      sc.state.selected_index = 3

      sc:move('down')
      eq(1, sc.state.selected_index)
    end)

    it('should wrap to last item when moving up past first', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.state.filtered_items = {
        { label = 'a' },
        { label = 'b' },
        { label = 'c' },
      }
      sc.state.selected_index = 1

      sc:move('up')
      eq(3, sc.state.selected_index)
    end)

    it('should be a no-op when filtered_items is empty', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.state.filtered_items = {}
      sc.state.selected_index = 1

      sc:move('down')
      eq(1, sc.state.selected_index)

      sc:move('up')
      eq(1, sc.state.selected_index)
    end)
  end)

  describe('select', function()
    it('should call on_select with the value of the selected item', function()
      local selected_value = nil
      local sc = SearchComponent({
        items = {},
        on_select = function(value)
          selected_value = value
        end,
      })

      local obj = { id = 42 }
      sc.state.filtered_items = {
        { label = 'a', value = obj },
        { label = 'b', value = 'second' },
      }
      sc.state.selected_index = 1

      sc:select()
      eq(obj, selected_value)
    end)

    it('should use the item itself as value when value is not provided', function()
      local selected_value = nil
      local sc = SearchComponent({
        items = {},
        on_select = function(value)
          selected_value = value
        end,
      })

      local item = { label = 'main', description = 'default' }
      sc.state.filtered_items = { item }
      sc.state.selected_index = 1

      sc:select()
      eq(item, selected_value)
    end)

    it('should not error when filtered_items is empty', function()
      local called = false
      local sc = SearchComponent({
        items = {},
        on_select = function()
          called = true
        end,
      })

      sc.state.filtered_items = {}
      sc.state.selected_index = 1

      -- Should not error
      sc:select()
      assert.is_false(called)
    end)

    it('should call on_select with correct item when selected_index is not 1', function()
      local selected_value = nil
      local sc = SearchComponent({
        items = {},
        on_select = function(value)
          selected_value = value
        end,
      })

      sc.state.filtered_items = {
        { label = 'a', value = 'first' },
        { label = 'b', value = 'second' },
        { label = 'c', value = 'third' },
      }
      sc.state.selected_index = 3

      sc:select()
      eq('third', selected_value)
    end)
  end)

  describe('get_selected_item', function()
    it('should return the currently selected item', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      local item = { label = 'main', description = 'default' }
      sc.state.filtered_items = { item, { label = 'develop' } }
      sc.state.selected_index = 1

      eq(item, sc:get_selected_item())
    end)

    it('should return nil when filtered_items is empty', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.state.filtered_items = {}
      sc.state.selected_index = 1

      assert.is_nil(sc:get_selected_item())
    end)

    it('should return correct item for non-first index', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      local second = { label = 'develop' }
      sc.state.filtered_items = { { label = 'main' }, second }
      sc.state.selected_index = 2

      eq(second, sc:get_selected_item())
    end)
  end)

  describe('close', function()
    it('should call on_close callback when provided', function()
      local closed = false
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
        on_close = function()
          closed = true
        end,
      })

      sc:close()
      assert.is_true(closed)
    end)

    it('should not error when on_close is not provided', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      -- Should not error
      sc:close()
    end)
  end)
end)
