local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Window = lazy('vgit.core.Window')
local Component = lazy('vgit.ui.Component')
local Element = lazy('vgit.ui.elements.Element')
local LayoutContext = lazy('vgit.ui.layout.LayoutContext')
local SearchFilter = lazy('vgit.ui.components.SearchComponent.SearchFilter')

local SearchComponent = Component:extend()

function SearchComponent:constructor(props)
  local instance = Component.constructor(self, props)

  instance._input_element = nil
  instance._list_element = nil
  instance._filter = SearchFilter()
  instance._autocmd_ids = {}
  instance._loading = false
  instance._exhausted = false

  return instance
end

function SearchComponent:get_initial_state()
  return {
    query = '',
    filtered_items = {},
    selected_index = 1,
  }
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
end

function SearchComponent:_load_more_items()
  if self._loading or self._exhausted then return end
  if not self.props.on_load_more then return end

  self._loading = true
  self:render()

  event.async(function()
    local new_items = self.props.on_load_more()

    vim.schedule(function()
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
    end)
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

  self:unmount()
end

function SearchComponent:get_selected_item()
  local items = self.state.filtered_items
  if #items == 0 then return nil end

  return items[self.state.selected_index]
end

function SearchComponent:_get_width()
  local width = self.props.width or '60vw'
  return LayoutContext.convert_dimension(width) or width
end

function SearchComponent:_get_col()
  local width = self:_get_width()
  return math.floor((vim.o.columns - width) / 2)
end

function SearchComponent:component_will_mount()
  local width = self:_get_width()
  local col = self:_get_col()
  local row = 0
  local zindex = self.props.zindex or 50
  local border_hl = self.props.border_hl or 'GitBorder'
  local winhl = 'Normal:GitBackground,FloatBorder:' .. border_hl
  local list_winhl = 'Normal:GitBackground,FloatBorder:' .. border_hl .. ',CursorLine:GitSelected'

  local input_border = self.props.border or { '', '', '', '│', '', '', '', '│' }
  local list_border = { '├', '─', '┤', '│', '╯', '─', '╰', '│' }

  local list_row = row + 1

  if not self._input_element then
    self._input_element = Element({
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
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = 1,
        style = 'minimal',
        focusable = true,
        focus = true,
        zindex = zindex + 1,
        border = input_border,
      },
    })
  end

  if not self._list_element then
    self._list_element = Element({
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
        relative = 'editor',
        row = list_row,
        col = col,
        width = width,
        height = 1,
        style = 'minimal',
        focusable = false,
        zindex = zindex,
        border = list_border,
      },
    })
  end
end

function SearchComponent:mount()
  if self._mounted then return end

  Component.mount(self)

  self._input_element:mount()
  self._list_element:mount()

  local prompt = self.props.prompt or '> '
  self._input_element:set_lines({ prompt })

  self:_setup_input_tracking()
  self:_setup_keymaps()
  self:_setup_close_autocmds()

  self:_apply_filter()

  self._input_element:focus()
  vim.cmd('startinsert!')
end

function SearchComponent:_setup_input_tracking()
  local prompt = self.props.prompt or '> '
  local input_buf = self._input_element:get_buffer()

  input_buf:attach_to_changes({
    on_lines = function()
      vim.schedule(function()
        if not self._mounted then return end
        if not input_buf:is_valid() then return end

        local lines = input_buf:get_lines(0, 1)
        local line = lines[1] or ''

        if not vim.startswith(line, prompt) then
          line = prompt
          input_buf:set_lines({ line }, 0, 1)
          local col = #prompt
          local win = self._input_element:get_window()
          win:set_cursor({ 1, col })
          return
        end

        local query = line:sub(#prompt + 1)

        if query ~= self.state.query then
          self.state.query = query
          self:_apply_filter()
        end
      end)
    end,
  })
end

function SearchComponent:_setup_keymaps()
  local input_element = self._input_element

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

function SearchComponent:_setup_close_autocmds()
  local input_buf = self._input_element:get_buffer()
  if not input_buf then return end

  -- BufWipeout fires exactly once when the buffer is destroyed; no need to track the ID.
  input_buf:on('BufWipeout', function()
    if self._mounted then
      -- The input buffer is already being wiped, so clear the reference
      -- to prevent unmount() from trying to delete it again (E937).
      self._input_element = nil
      self:close()
    end
  end)

  local input_win = self._input_element:get_window()
  local list_win = self._list_element:get_window()

  local leave_id = vim.api.nvim_create_autocmd('WinLeave', {
    group = 'VGitGroup',
    callback = function()
      vim.defer_fn(function()
        if not self._mounted then return end

        local current_win = Window.get_current()
        if not current_win:is_same(input_win) and not current_win:is_same(list_win) then self:close() end
      end, 50)
    end,
  })
  self._autocmd_ids[#self._autocmd_ids + 1] = leave_id
end

function SearchComponent:render()
  if not self._list_element or not self._list_element:is_valid() then return end

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

  local list_height = math.min(max_height, math.max(1, #lines))

  self._list_element:set_lines(lines)

  for i = 1, #description_hls do
    local hl = description_hls[i]
    self._list_element:place_extmark_highlight({
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
    self._list_element:place_extmark_highlight({
      hl = hl.hl,
      row = hl.row,
      col_range = {
        from = hl.col_from,
        to = hl.col_to,
      },
    })
  end

  if self._list_element:is_valid() then
    self._list_element:set_height(list_height)

    local selected = self.state.selected_index
    if selected >= 1 and selected <= visible_count then
      local win = self._list_element:get_window()
      if win then win:set_cursor({ selected, 0 }) end
    end
  end

  if #items == 0 then
    local placeholder = self.props.placeholder or 'Search...'
    self._list_element:set_lines({ '' })
    self._list_element:place_extmark_text({
      text = padding .. placeholder,
      hl = 'GitComment',
      row = 0,
      col = 0,
    })
  end

  if self._input_element and self._input_element:is_valid() then
    local count_text = tostring(#(self.props.items or {}))
    self._input_element:place_extmark_text({
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

function SearchComponent:unmount()
  if not self._mounted then return end

  vim.cmd('stopinsert')

  for i = 1, #self._autocmd_ids do
    vim.api.nvim_del_autocmd(self._autocmd_ids[i])
  end
  self._autocmd_ids = {}

  if self._input_element then
    self._input_element:unmount()
    self._input_element = nil
  end

  if self._list_element then
    self._list_element:unmount()
    self._list_element = nil
  end

  Component.unmount(self)
end

return SearchComponent
