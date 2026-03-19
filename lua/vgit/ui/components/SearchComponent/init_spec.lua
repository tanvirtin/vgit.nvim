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

local function make_mock_element(opts)
  opts = opts or {}
  local events = {}

  return {
    is_valid = function()
      return opts.valid ~= false
    end,
    focus = function() end,
    get_window = function()
      return {
        get_cursor = function()
          return { 1, 0 }
        end,
        set_cursor = function() end,
        start_insert = function() end,
      }
    end,
    get_buffer = function()
      return {
        on = function() end,
        attach_to_changes = function() end,
        is_valid = function()
          return opts.valid ~= false
        end,
        get_lines = function()
          return { '> ' }
        end,
        set_lines = function() end,
      }
    end,
    on = function(_, event_name, callback)
      events[event_name] = callback
    end,
    set_keymap = function() end,
    set_lines = function() end,
    set_height = function() end,
    place_extmark_highlight = function() end,
    place_extmark_text = function() end,
    unmount = function() end,
    _events = events,
  }
end

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
      assert.is_nil(sc.elements.input)
      assert.is_nil(sc.elements.list)
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

    it('should fire on_move after filtering', function()
      local moved_item = nil
      local sc = SearchComponent({
        items = {
          { label = 'main' },
          { label = 'develop' },
        },
        on_select = function() end,
        on_move = function(item)
          moved_item = item
        end,
      })

      sc.state.query = ''
      sc:_apply_filter()

      assert.is_not_nil(moved_item)
      eq('main', moved_item.label)
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

    it('should fire on_move callback after moving', function()
      local moved_items = {}
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
        on_move = function(item)
          moved_items[#moved_items + 1] = item
        end,
      })

      sc.state.filtered_items = {
        { label = 'a' },
        { label = 'b' },
        { label = 'c' },
      }
      sc.state.selected_index = 1

      sc:move('down')
      eq(1, #moved_items)
      eq('b', moved_items[1].label)

      sc:move('down')
      eq(2, #moved_items)
      eq('c', moved_items[2].label)
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

  describe('on', function()
    it('should delegate to both elements', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.elements.list = make_mock_element()
      sc.elements.input = make_mock_element()

      local list_called = false
      local input_called = false

      sc.elements.list.on = function(_, event_name)
        if event_name == 'BufWinLeave' then list_called = true end
      end
      sc.elements.input.on = function(_, event_name)
        if event_name == 'BufWinLeave' then input_called = true end
      end

      sc:on('BufWinLeave', function() end)

      assert.is_true(list_called)
      assert.is_true(input_called)
    end)

    it('should not error when elements are nil', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      -- Should not error
      sc:on('BufWinLeave', function() end)
    end)
  end)

  describe('set_items', function()
    it('should update items and reset state', function()
      local sc = SearchComponent({
        items = { { label = 'old' } },
        on_select = function() end,
      })

      sc.state.selected_index = 5

      local new_items = { { label = 'new1' }, { label = 'new2' } }
      sc:set_items(new_items)

      eq(new_items, sc.props.items)
      eq(new_items, sc.state.filtered_items)
      eq(1, sc.state.selected_index)
    end)

    it('should handle nil items', function()
      local sc = SearchComponent({
        items = { { label = 'old' } },
        on_select = function() end,
      })

      sc:set_items(nil)

      eq({}, sc.props.items)
      eq({}, sc.state.filtered_items)
    end)

    it('should respect page_size', function()
      local sc = SearchComponent({
        items = {},
        page_size = 2,
        on_select = function() end,
      })

      sc:set_items({ { label = 'a' }, { label = 'b' }, { label = 'c' } })

      eq(2, sc.state.visible_count)
    end)

    it('should fire on_move after setting items', function()
      local moved_item = nil
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
        on_move = function(item)
          moved_item = item
        end,
      })

      sc:set_items({ { label = 'first' }, { label = 'second' } })

      assert.is_not_nil(moved_item)
      eq('first', moved_item.label)
    end)
  end)

  describe('is_valid', function()
    it('should return false when no elements exist', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      assert.is_false(sc:is_valid())
    end)

    it('should return true when input element is valid', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.elements.input = make_mock_element({ valid = true })

      assert.is_true(sc:is_valid())
    end)

    it('should return true when list element is valid', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.elements.list = make_mock_element({ valid = true })

      assert.is_true(sc:is_valid())
    end)

    it('should return false when both elements are invalid', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.elements.input = make_mock_element({ valid = false })
      sc.elements.list = make_mock_element({ valid = false })

      assert.is_false(sc:is_valid())
    end)
  end)

  describe('set_keymap', function()
    it('should delegate to input element', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      local called_with = nil
      sc.elements.input = make_mock_element()
      sc.elements.input.set_keymap = function(_, mode, key, handler, desc)
        called_with = { mode = mode, key = key, desc = desc }
      end

      sc:set_keymap('n', 'q', function() end, 'Quit')

      assert.is_not_nil(called_with)
      eq('n', called_with.mode)
      eq('q', called_with.key)
      eq('Quit', called_with.desc)
    end)

    it('should not error when input element is nil', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      -- Should not error
      sc:set_keymap('n', 'q', function() end, 'Quit')
    end)
  end)

  describe('layout mode (popup = false)', function()
    it('should default to popup mode', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      -- popup defaults to true (popup ~= false)
      assert.is_true(sc.props.popup ~= false)
    end)

    it('should accept popup = false', function()
      local sc = SearchComponent({
        items = {},
        popup = false,
        on_select = function() end,
      })

      eq(false, sc.props.popup)
    end)
  end)

  describe('_fire_on_move', function()
    it('should call on_move with current selected item', function()
      local moved_item = nil
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
        on_move = function(item)
          moved_item = item
        end,
      })

      sc.state.filtered_items = {
        { label = 'a' },
        { label = 'b' },
      }
      sc.state.selected_index = 2

      sc:_fire_on_move()

      assert.is_not_nil(moved_item)
      eq('b', moved_item.label)
    end)

    it('should not error when on_move is not provided', function()
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
      })

      sc.state.filtered_items = { { label = 'a' } }
      sc.state.selected_index = 1

      -- Should not error
      sc:_fire_on_move()
    end)

    it('should not call on_move when no items', function()
      local called = false
      local sc = SearchComponent({
        items = {},
        on_select = function() end,
        on_move = function()
          called = true
        end,
      })

      sc.state.filtered_items = {}
      sc.state.selected_index = 1

      sc:_fire_on_move()

      assert.is_false(called)
    end)
  end)
end)
