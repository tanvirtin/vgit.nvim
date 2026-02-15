local vim = vim
local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
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

  return instance
end

function SearchComponent:get_initial_state()
  return {
    query = '',
    filtered_items = {},
    selected_index = 1,
  }
end

function SearchComponent:_apply_filter()
  local items = self.props.items or {}
  local query = self.state.query

  local filtered_items
  if self.props.on_search then
    filtered_items = self.props.on_search(query, items)
  else
    filtered_items = self._filter:filter(items, query)
  end

  self:set_state({
    filtered_items = filtered_items or {},
    selected_index = 1,
  })
end

function SearchComponent:move(direction)
  local items = self.state.filtered_items
  if #items == 0 then return end

  local index = self.state.selected_index

  if direction == 'down' then
    index = index + 1
    if index > #items then index = 1 end
  elseif direction == 'up' then
    index = index - 1
    if index < 1 then index = #items end
  end

  self:set_state({ selected_index = index })
end

function SearchComponent:select()
  local items = self.state.filtered_items

  if #items == 0 then
    if self.props.on_no_match then
      self.props.on_no_match(self.state.query)
    end
    return
  end

  local item = items[self.state.selected_index]
  if not item then return end

  local value = item.value ~= nil and item.value or item

  if self.props.on_select then
    self.props.on_select(value)
  end
end

function SearchComponent:close()
  if self.props.on_close then
    self.props.on_close()
  end

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
  local zindex = self.props.zindex or 50
  local border = self.props.border or { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }
  local border_hl = self.props.border_hl or 'GitBorder'
  local winhl = 'Normal:GitBackground,FloatBorder:' .. border_hl
  -- Input takes 1 row of content; border adds 2 rows (top + bottom).
  local list_row = border and 3 or 1

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
        row = 0,
        col = col,
        width = width,
        height = 1,
        style = 'minimal',
        focusable = true,
        focus = true,
        zindex = zindex + 1,
        border = border,
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
        winhl = winhl,
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
        border = border,
      },
    })
  end
end

function SearchComponent:mount()
  if self.mounted then return end

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
  local input_buffer = self._input_element.buffer

  input_buffer:attach_to_changes({
    on_lines = function()
      vim.schedule(function()
        if not self.mounted then return end
        if not input_buffer:is_valid() then return end

        local lines = input_buffer:get_lines(0, 1)
        local line = lines[1] or ''

        if not vim.startswith(line, prompt) then
          line = prompt
          input_buffer:set_lines({ line }, 0, 1)
          local col = #prompt
          pcall(vim.api.nvim_win_set_cursor, self._input_element.window.win_id, { 1, col })
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
  local input_bufnr = self._input_element:get_bufnr()
  if not input_bufnr then return end

  local wipeout_id = vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = input_bufnr,
    callback = function()
      if self.mounted then
        -- The input buffer is already being wiped, so clear the reference
        -- to prevent unmount() from trying to delete it again (E937).
        self._input_element = nil
        self:close()
      end
    end,
  })
  self._autocmd_ids[#self._autocmd_ids + 1] = wipeout_id

  local input_win_id = self._input_element:get_win_id()
  local list_win_id = self._list_element:get_win_id()

  local leave_id = vim.api.nvim_create_autocmd('WinLeave', {
    buffer = input_bufnr,
    callback = function()
      vim.defer_fn(function()
        if not self.mounted then return end

        local current_win = vim.api.nvim_get_current_win()
        if current_win ~= input_win_id and current_win ~= list_win_id then
          self:close()
        end
      end, 50)
    end,
  })
  self._autocmd_ids[#self._autocmd_ids + 1] = leave_id
end

function SearchComponent:render()
  if not self._list_element or not self._list_element:is_valid() then return end

  local items = self.state.filtered_items
  local max_height = self.props.max_height or 20

  local lines = {}
  local description_hls = {}

  for i = 1, #items do
    local item = items[i]
    local line = item.label or ''

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

  local list_height = math.min(max_height, math.max(1, #lines))

  self._list_element.buffer:set_lines(lines)

  for i = 1, #description_hls do
    local hl = description_hls[i]
    self._list_element.buffer:place_extmark_highlight({
      hl = 'GitComment',
      row = hl.row,
      col_range = {
        from = hl.col_from,
        to = hl.col_to,
      },
    })
  end

  if self._list_element.window and self._list_element.window:is_valid() then
    self._list_element.window:set_height(list_height)

    local selected = self.state.selected_index
    if selected >= 1 and selected <= #lines then
      pcall(vim.api.nvim_win_set_cursor, self._list_element.window.win_id, { selected, 0 })
    end
  end

  if #items == 0 then
    local placeholder = self.props.placeholder or 'Search...'
    self._list_element.buffer:set_lines({ '' })
    self._list_element.buffer:place_extmark_text({
      text = placeholder,
      hl = 'GitComment',
      row = 0,
      col = 0,
    })
  end
end

function SearchComponent:unmount()
  if not self.mounted then return end

  vim.cmd('stopinsert')

  for i = 1, #self._autocmd_ids do
    pcall(vim.api.nvim_del_autocmd, self._autocmd_ids[i])
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
