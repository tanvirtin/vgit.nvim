local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Element = lazy('vgit.ui.elements.Element')
local Component = lazy('vgit.ui.Component')
local SearchFilter = lazy('vgit.core.SearchFilter')

local SearchComponent = Component({
  elements = {
    input = { buf_options = { modifiable = true, buflisted = false, bufhidden = 'wipe' } },
    list = { buf_options = { modifiable = false, buflisted = false, bufhidden = 'wipe' } },
  },

  on_mount = function(self)
    local prompt = self.props.prompt or '> '
    self.elements.input:set_lines({ prompt })

    self:_setup_input_tracking()
    self:_setup_keymaps()
    self:_apply_filter()

    if self.props.popup == false then
      self.elements.list:on('CursorMoved', function()
        if not self._mounted then return end
        local cursor = self.elements.list:get_cursor()
        if not cursor then return end
        local lnum = cursor[1]
        if lnum ~= self.state.selected_index then
          self.state.selected_index = lnum
          self:_fire_on_move()
        end
      end)
    end

    self.elements.input:focus()
    self.elements.input:start_insert()
  end,

  on_unmount = function(self)
    if self.elements.input then self.elements.input:stop_insert() end
  end,
})

function SearchComponent:constructor(props)
  local instance = SearchComponent.super.constructor(self, props)

  instance.elements = {}
  instance._loading = false
  instance._exhausted = false
  instance._filter = SearchFilter()

  return instance
end

function SearchComponent:get_initial_state()
  return {
    query = '',
    filtered_items = {},
    selected_index = 1,
  }
end

function SearchComponent:mount()
  if self._mounted then return end
  local border_hl = self.props.border_hl or 'GitBorder'
  local winhl = 'Normal:GitBackground,FloatBorder:' .. border_hl
  local list_winhl = 'Normal:GitBackground,FloatBorder:' .. border_hl .. ',CursorLine:GitSelected'

  local is_popup = self.props.popup ~= false
  local input_border = is_popup and (self.props.border or { '', '', '', '│', '', '', '', '│' }) or 'none'
  local list_border = is_popup and { '├', '─', '┤', '│', '╯', '─', '╰', '│' } or 'none'
  local list_focusable = not is_popup

  if not self.elements.input then
    self.elements.input = Element({
      buf_options = {
        modifiable = true,
        buflisted = false,
        bufhidden = 'wipe',
      },
      win_options = {
        cursorline = false,
        number = false,
        relativenumber = false,
        wrap = false,
        winhl = winhl,
      },
      win_plot = {
        focusable = true,
        border = input_border,
      },
    })
  end

  if not self.elements.list then
    self.elements.list = Element({
      buf_options = {
        modifiable = false,
        buflisted = false,
        bufhidden = 'wipe',
      },
      win_options = {
        cursorline = true,
        number = false,
        relativenumber = false,
        wrap = false,
        winhl = list_winhl,
      },
      win_plot = {
        focusable = list_focusable,
        border = list_border,
      },
    })
  end
  self._mounted = true
end

function SearchComponent:layout(spec)
  local LayoutBounds = require('vgit.ui.layout.LayoutBounds')
  local zindex = self.props.zindex or 50

  if self.props.popup ~= false then
    local width = self.props.width or '60vw'
    width = LayoutBounds.convert_dimension(width) or width

    return spec.absolute(
      spec.vertical({
        spec.view(self.elements.input, { height = 1, zindex = zindex + 1 }),
        spec.view(self.elements.list, { flex = 1, zindex = zindex }),
      }),
      {
        anchor = spec.Anchor.TOP_CENTER,
        width = width,
        height = 1 + (self.props.max_height or 20),
      }
    )
  end

  return spec.flex({
    direction = spec.Direction.VERTICAL,
    children = {
      spec.view(self.elements.input, { height = 1, zindex = zindex + 1 }),
      spec.view(self.elements.list, { flex = 1, zindex = zindex }),
    },
    height = self.props.height,
    flex = self.props.flex,
  })
end

function SearchComponent:is_valid()
  if self.elements.input and self.elements.input:is_valid() then return true end
  if self.elements.list and self.elements.list:is_valid() then return true end
  return false
end

function SearchComponent:on(event_name, callback)
  if self.elements.list then self.elements.list:on(event_name, callback) end
  if self.elements.input then self.elements.input:on(event_name, callback) end
end

function SearchComponent:set_keymap(mode_or_opts, key_or_callback, handler, desc)
  if self.elements.input then self.elements.input:set_keymap(mode_or_opts, key_or_callback, handler, desc) end
end

function SearchComponent:set_items(items)
  self._loading = false
  self.props.items = items or {}
  self._exhausted = false

  local filtered_items = self.props.items
  local page_size = self.props.page_size

  self:set_state({
    filtered_items = filtered_items,
    selected_index = 1,
    visible_count = page_size and math.min(page_size, #filtered_items) or #filtered_items,
  })
  self:_fire_on_move()
end

function SearchComponent:_fire_on_move()
  if not self.props.on_move then return end

  local item = self.state.filtered_items[self.state.selected_index]
  if item then self.props.on_move(item) end
end

function SearchComponent:_apply_filter()
  local items = self.props.items or {}
  local query = self.state.query

  if self.props.on_search_async then
    self._exhausted = false
    self.props.on_search_async(query)
    return
  end

  local filtered_items
  if self.props.on_search then
    filtered_items = self.props.on_search(query, items)
  else
    filtered_items = self._filter:filter(items, query)
  end

  filtered_items = filtered_items or {}
  local page_size = self.props.page_size

  self._exhausted = false

  self:set_state({
    filtered_items = filtered_items,
    selected_index = 1,
    visible_count = page_size and math.min(page_size, #filtered_items) or #filtered_items,
  })
  self:_fire_on_move()
end

function SearchComponent:_load_more_items()
  if self._loading or self._exhausted then return end
  if not self.props.on_load_more then return end

  self._loading = true
  self:render()

  event.async(function()
    local new_items = self.props.on_load_more()

    event.await()

    self._loading = false

    if not self._mounted then return end

    if not new_items or #new_items == 0 then
      self._exhausted = true
      self:render()
      return
    end

    local items = self.props.items or {}
    for i = 1, #new_items do
      items[#items + 1] = new_items[i]
    end

    local prev_visible = self.state.visible_count or 0
    local prev_index = self.state.selected_index

    self:_apply_filter()
    local filtered = self.state.filtered_items
    local new_visible = math.min(prev_visible + #new_items, #filtered)
    self:set_state({ visible_count = new_visible, selected_index = prev_index })
  end)()
end

function SearchComponent:move(direction)
  local items = self.state.filtered_items
  if #items == 0 then return end

  local visible_count = math.min(self.state.visible_count or #items, #items)
  if visible_count == 0 then return end

  local index = self.state.selected_index

  if direction == 'down' then
    index = index + 1
    if index > visible_count then
      if visible_count < #items then
        local page_size = self.props.page_size or visible_count
        local new_visible = math.min(visible_count + page_size, #items)
        self:set_state({ visible_count = new_visible, selected_index = index })
        if self._mounted then self:render() end
        self:_fire_on_move()
        return
      elseif self.props.on_load_more and not self._exhausted then
        if not self._loading then self:_load_more_items() end
        return
      else
        index = 1
      end
    end
  elseif direction == 'up' then
    index = index - 1
    if index < 1 then index = visible_count end
  end

  self:set_state({ selected_index = index })
  self:_fire_on_move()
end

function SearchComponent:select()
  local items = self.state.filtered_items

  if #items == 0 then
    if self.props.on_no_match then self.props.on_no_match(self.state.query) end
    return
  end

  local item = items[self.state.selected_index]
  if not item then return end

  local value = item.value ~= nil and item.value or item

  if self.props.on_select then self.props.on_select(value) end
end

function SearchComponent:close()
  if self.props.on_close then self.props.on_close() end
end

function SearchComponent:get_selected_item()
  local items = self.state.filtered_items
  if #items == 0 then return nil end

  return items[self.state.selected_index]
end

function SearchComponent:_setup_input_tracking()
  local prompt = self.props.prompt or '> '

  self.elements.input:attach_to_changes({
    on_lines = event.async(function()
      event.await()

      if not self._mounted then return end
      if not self.elements.input or not self.elements.input:is_valid() then return end

      local lines = self.elements.input:get_lines()
      local line = lines[1] or ''

      if not vim.startswith(line, prompt) then
        line = prompt
        self.elements.input:set_lines({ line })
        self.elements.input:set_cursor({ 1, #prompt })
        return
      end

      local query = line:sub(#prompt + 1)

      if query ~= self.state.query then
        self.state.query = query
        self:_apply_filter()
      end
    end),
  })
end

function SearchComponent:_setup_keymaps()
  local input_element = self.elements.input

  input_element:set_keymap('i', '<C-n>', function()
    self:move('down')
  end, 'Move down')

  input_element:set_keymap('i', '<Down>', function()
    self:move('down')
  end, 'Move down')

  input_element:set_keymap('i', '<C-p>', function()
    self:move('up')
  end, 'Move up')

  input_element:set_keymap('i', '<Up>', function()
    self:move('up')
  end, 'Move up')

  input_element:set_keymap('i', '<CR>', function()
    self:select()
  end, 'Select item')

  input_element:set_keymap('i', '<Esc>', function()
    self:close()
  end, 'Close')

  input_element:set_keymap('i', '<C-c>', function()
    self:close()
  end, 'Close')

  input_element:set_keymap('n', '<Esc>', function()
    self:close()
  end, 'Close')

  input_element:set_keymap('n', '<C-c>', function()
    self:close()
  end, 'Close')

  input_element:set_keymap('n', 'q', function()
    self:close()
  end, 'Close')
end

function SearchComponent:render()
  if not self.elements.list or not self.elements.list:is_valid() then return end

  local items = self.state.filtered_items
  local max_height = self.props.max_height or 20
  local visible_count = math.min(self.state.visible_count or #items, #items)
  local padding = ' '

  local lines = {}
  local description_hls = {}
  local icon_hls = {}

  for i = 1, visible_count do
    local item = items[i]
    local line = padding

    if item.icon then
      local icon_start = #line
      line = line .. item.icon .. ' '
      icon_hls[#icon_hls + 1] = {
        row = i - 1,
        col_from = icon_start,
        col_to = icon_start + #item.icon,
        hl = item.icon_hl or 'GitSignsAdd',
      }
    end

    line = line .. (item.label or '')

    if item.description then
      local desc_start = #line
      line = line .. '  ' .. item.description
      description_hls[#description_hls + 1] = {
        row = i - 1,
        col_from = desc_start + 2,
        col_to = #line,
      }
    end

    lines[#lines + 1] = line
  end

  if self._loading then
    local loading_line = padding .. 'Loading...'
    lines[#lines + 1] = loading_line
    description_hls[#description_hls + 1] = {
      row = #lines - 1,
      col_from = 0,
      col_to = #loading_line,
    }
  elseif visible_count < #items then
    local remaining = #items - visible_count
    local more_line = padding .. string.format('... %d more', remaining)
    lines[#lines + 1] = more_line
    description_hls[#description_hls + 1] = {
      row = #lines - 1,
      col_from = 0,
      col_to = #more_line,
    }
  end

  self.elements.list:set_lines(lines)

  for i = 1, #description_hls do
    local hl = description_hls[i]
    self.elements.list:place_extmark_highlight({
      hl = 'GitComment',
      row = hl.row,
      col_range = {
        from = hl.col_from,
        to = hl.col_to,
      },
    })
  end

  for i = 1, #icon_hls do
    local hl = icon_hls[i]
    self.elements.list:place_extmark_highlight({
      hl = hl.hl,
      row = hl.row,
      col_range = {
        from = hl.col_from,
        to = hl.col_to,
      },
    })
  end

  if self.elements.list:is_valid() then
    if self.props.popup ~= false then
      local list_height = math.min(max_height, math.max(1, #lines))
      self.elements.list:set_height(list_height)
    end

    local selected = self.state.selected_index
    if selected >= 1 and selected <= visible_count then self.elements.list:set_cursor({ selected, 0 }) end
  end

  if #items == 0 then
    local placeholder = self.props.placeholder or 'Search...'
    self.elements.list:set_lines({ '' })
    self.elements.list:place_extmark_text({
      text = padding .. placeholder,
      hl = 'GitComment',
      row = 0,
      col = 0,
    })
  end

  if self.elements.input and self.elements.input:is_valid() then
    local count_text = tostring(#(self.props.items or {}))
    self.elements.input:place_extmark_text({
      text = count_text,
      hl = 'GitComment',
      row = 0,
      col = 0,
      pos = 'right_align',
    })
  end
end

function SearchComponent:set_loading(value)
  self._loading = value
  if self._mounted then self:render() end
end

return SearchComponent
