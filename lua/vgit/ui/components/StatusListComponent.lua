local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local icons = require('vgit.core.icons')
local Component = require('vgit.ui.Component')
local Element = require('vgit.ui.elements.Element')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local symbols_setting = require('vgit.settings.symbols')

local StatusListComponent = Component:extend()

function StatusListComponent:constructor(props)
  return {
    props = props or {},
    mounted = false,
    state = {
      list = props.list or {},
      title = props.title or '',
      hls = {},
      virtual_texts = {},
      shadow_list = {},
    },
    _element = nil,
    _on_enter_callback = nil,
    _on_move_callback = nil,
  }
end

function StatusListComponent:set_list(list)
  self.state.list = list
  return self
end

function StatusListComponent:set_title(text)
  self.state.title = text
  return self
end

function StatusListComponent:set_raw_entries(entries, metadata)
  local transformed_list = self:transform_entries_to_tree(entries, metadata)
  self.state.list = transformed_list
  return self
end

function StatusListComponent:get_parent_folder(segmented_folders, current_index)
  local acc = ''
  local count = 1
  local separator = fs.sep

  for i = 1, #segmented_folders do
    if i == current_index then return acc, count end

    local foldername = segmented_folders[i]

    count = count + 1
    acc = string.format('%s%s%s', acc, separator, foldername)
  end

  return acc, count
end

function StatusListComponent:derive_status_hl(status)
  if status:is_staged() then
    if status:has('A*') or status:has('C*') or status:has('R*') then return 'GitSignsAdd' end
    if status:has('D*') then return 'GitSignsDelete' end
    if status:has_either('MT') then return 'GitSignsChange' end
  end

  if status:is_unstaged() then
    if status:has('??') then return 'GitSignsAdd' end
    if status:has('*R') or status:has('*C') then return 'GitSignsAdd' end
    if status:has('*D') then return 'GitSignsDelete' end
    if status:has('*M') or status:has('*T') then return 'GitSignsChange' end
  end

  if status:is_unmerged() then return 'GitSignsChange' end

  return 'GitLineNr'
end

function StatusListComponent:create_node(entry, metadata)
  if entry.status then
    local id = entry.id
    local status = entry.status
    local filename = status.filename
    local filetype = status.filetype
    local icon, icon_hl = icons.get(filename, filetype)

    -- Extract just the filename from the full path
    local display_name = filename
    if filename then
      local path_parts = vim.split(filename, fs.sep)
      display_name = path_parts[#path_parts] or filename
    end

    local node = {
      id = id,
      entry = entry,
      value = display_name, -- Use just the filename as the display value
      metadata = metadata,
      virtual_text = {
        before = {
          text = status.value,
          hl = self:derive_status_hl(status),
        },
      },
    }

    if icon then node.icon_before = {
      icon = icon,
      hl = icon_hl,
    } end

    return node
  end

  return {
    items = {},
    open = true,
    entry = entry,
    value = entry.current or 'Unknown', -- Fallback for folder nodes
    metadata = metadata,
    icon_before = function(item)
      return { icon = item.open and '' or '' }
    end,
  }
end

function StatusListComponent:find_parent(entry, tree)
  local function _find(tree)
    if not tree then return nil end

    for i = 1, #tree do
      local node = tree[i]

      if node.entry.path == entry.parent then
        return node.items
      else
        local found = _find(node.items)
        if found then return found end
      end
    end
  end

  return _find(tree)
end

function StatusListComponent:normalize_entries(entries)
  local normalized_entries = {}
  local separator = fs.sep

  for i = 1, #entries do
    local entry = entries[i]

    local id = entry.id
    local status = entry.status
    local entry_type = entry.type
    local filename = status.filename

    -- Split the filename by its separator and create a list of all folders.
    local segmented_folders = vim.split(filename, separator)

    -- Loop over each segment and create paths by concatenating 1..i items in
    -- the segmented folder, storing all the necessary metadata in the process.
    for j = 1, #segmented_folders do
      local parent_folder_name, depth = self:get_parent_folder(segmented_folders, j)
      local current_folder_name = segmented_folders[j]
      local path = string.format('%s%s%s', parent_folder_name, separator, current_folder_name)

      normalized_entries[path] = {
        id = id,
        path = path,
        depth = depth,
        type = entry_type,
        parent = parent_folder_name,
        current = current_folder_name,
        status = j == #segmented_folders and status or nil,
      }
    end
  end

  local normalized_entries_by_depth = {}

  for _, entry in pairs(normalized_entries) do
    local depth_list = normalized_entries_by_depth[entry.depth]

    if not depth_list then
      normalized_entries_by_depth[entry.depth] = { entry }
    else
      depth_list[#depth_list + 1] = entry
    end
  end

  return normalized_entries_by_depth
end

function StatusListComponent:generate_tree(normalized_entries, metadata)
  local tree = {}

  for i = 1, #normalized_entries do
    local entries = normalized_entries[i]
    for j = 1, #entries do
      local entry = entries[j]
      local parent = self:find_parent(entry, tree) or tree
      parent[#parent + 1] = self:create_node(entry, metadata)
    end
  end

  return tree
end

function StatusListComponent:sort_tree(tree)
  local function sort_tree(list)
    local folders = {}
    local files = {}

    for i = 1, #list do
      local item = list[i]
      if item.items then
        folders[#folders + 1] = item
      else
        files[#files + 1] = item
      end
    end

    local sort_fn = function(entry1, entry2)
      return entry1.value < entry2.value
    end

    table.sort(folders, sort_fn)
    table.sort(files, sort_fn)

    return utils.list.merge(folders, files)
  end

  local function _sort_tree(tree)
    for i = 1, #tree do
      local item = tree[i]
      if item.items then
        item.items = sort_tree(item.items)
        _sort_tree(item.items)
      end
    end
  end

  tree = sort_tree(tree)
  _sort_tree(tree)

  return tree
end

function StatusListComponent:transform_entries_to_tree(entries, metadata)
  local normalized_entries = self:normalize_entries(entries)
  local tree = self:generate_tree(normalized_entries, metadata)
  return self:sort_tree(tree)
end

function StatusListComponent:toggle_list_item(item)
  if item.items then item.open = not item.open end
  return self
end

function StatusListComponent:is_fold(item)
  return item and item.items and #item.items > 0
end

function StatusListComponent:get_list_item(lnum)
  return self.state.shadow_list[lnum]
end

function StatusListComponent:each_list_item(callback)
  for lnum, item in pairs(self.state.shadow_list) do
    callback(item, lnum)
  end
end

function StatusListComponent:find_list_item(callback)
  for lnum, item in pairs(self.state.shadow_list) do
    if callback(item, lnum) then return item, lnum end
  end
end

function StatusListComponent:find_status(callback)
  return self:find_list_item(function(node, lnum)
    local status = node.entry and node.entry.status or nil
    if not status then return false end
    local entry_type = node.entry.type
    return callback(status, entry_type, lnum) == true
  end)
end

function StatusListComponent:each_status(callback)
  self:each_list_item(function(node, lnum)
    local status = node.entry and node.entry.status or nil
    if not status then return false end
    local entry_type = node.entry.type
    callback(status, entry_type, lnum)
  end)
end

function StatusListComponent:move_to(callback)
  local status, lnum = self:find_status(callback)
  if not status then return end

  if self._element and self._element:is_valid() then self._element:set_lnum(lnum) end

  return status
end

function StatusListComponent:get_current_list_item()
  if not self._element or not self._element:is_valid() then return nil end

  local lnum = self._element:get_lnum()
  return self:get_list_item(lnum)
end

function StatusListComponent:move(direction)
  if not self._element or not self._element:is_valid() then return nil end

  local lnum = self._element:get_lnum()
  local count = self._element:get_line_count()

  if direction == 'down' then lnum = lnum + 1 end
  if direction == 'up' then lnum = lnum - 1 end

  if lnum < 1 then
    lnum = count
  elseif lnum > count then
    lnum = 1
  end

  self._element:set_lnum(lnum)

  return self:get_list_item(lnum)
end

function StatusListComponent:toggle_current_list_item()
  if not self._element or not self._element:is_valid() then return end

  local lnum = self._element:get_lnum()
  local item = self:get_list_item(lnum)

  if item and item.open ~= nil then item.open = not item.open end

  self:sync()
end

function StatusListComponent:generate_lines()
  local spacing = 1
  local current_lnum = 0
  local depth_0_lnum = 0
  local item_count_for_depth_0 = 0

  local hls = {}
  local virtual_texts = {}
  local depth_0_item_counts = {}
  local foldable_list_shadow = {}

  -- Clear shadow list
  self.state.shadow_list = {}

  local function track_closed_folder_item_count(list, depth)
    if not list then return end

    for i = 1, #list do
      local item = list[i]
      local items = item.items
      if items then
        track_closed_folder_item_count(items, depth + 1)
      else
        item_count_for_depth_0 = item_count_for_depth_0 + 1
      end
    end
  end

  local function generate_lines_recursive(list, depth)
    if not list then return end

    for i = 1, #list do
      local item = list[i]
      current_lnum = current_lnum + 1

      if depth == 0 then
        depth_0_lnum = current_lnum
        item_count_for_depth_0 = 0
      end

      -- Memoizing recursion inside a flattened list, for O(1) memory access.
      self.state.shadow_list[current_lnum] = item

      local value = item.value
      local items = item.items
      local icon_before = item.icon_before
      local icon_after = item.icon_after
      local icon_hl_range_offset = 0

      if items then spacing = 2 end

      local indentation_count = spacing * depth

      if items then icon_hl_range_offset = 3 end

      if item.virtual_text then
        virtual_texts[#virtual_texts + 1] = {
          type = 'before',
          hl = item.virtual_text.before.hl,
          lnum = current_lnum,
          text = item.virtual_text.before.text,
        }
        indentation_count = indentation_count + 1
      end

      local indentation = string.rep(' ', indentation_count)

      if icon_before then
        if type(icon_before) == 'function' then icon_before = icon_before(item) end

        value = string.format('%s %s', icon_before.icon, value)
        hls[#hls + 1] = {
          hl = icon_before.hl,
          lnum = current_lnum,
          range = {
            top = indentation_count + icon_hl_range_offset,
            bot = indentation_count + icon_hl_range_offset + #icon_before.icon,
          },
        }
      elseif icon_after then
        if type(icon_after) == 'function' then icon_after = icon_after(item) end

        value = string.format('%s %s', value, icon_after.icon)
        hls[#hls + 1] = {
          hl = icon_after.hl,
          lnum = current_lnum,
          range = {
            top = indentation_count + icon_hl_range_offset + utils.str.length(value),
            bot = indentation_count + icon_hl_range_offset + utils.str.length(value) + #icon_after.icon,
          },
        }
      end

      if items then
        local fold_symbol = symbols_setting:get(item.open and 'open' or 'close')
        local fold_header = string.format('%s%s %s', indentation, fold_symbol, value)

        foldable_list_shadow[#foldable_list_shadow + 1] = fold_header
        hls[#hls + 1] = {
          hl = 'GitSymbol',
          lnum = current_lnum,
          range = {
            top = 1 + indentation_count,
            bot = 1 + indentation_count + #fold_symbol,
          },
        }
        hls[#hls + 1] = {
          hl = 'GitTitle',
          lnum = current_lnum,
          range = {
            top = 1 + indentation_count + #fold_symbol,
            bot = 1 + indentation_count + #fold_symbol + #value,
          },
        }

        if item.open then
          generate_lines_recursive(items, depth + 1)
        else
          track_closed_folder_item_count(items, depth + 1)
        end
        if depth == 0 then
          depth_0_item_counts[#depth_0_item_counts + 1] = {
            lnum = depth_0_lnum,
            count = item_count_for_depth_0,
          }
        end
      else
        item_count_for_depth_0 = item_count_for_depth_0 + 1
        foldable_list_shadow[#foldable_list_shadow + 1] = string.format('%s%s', indentation, value)
      end
    end
  end

  if not self.state.list then return {} end

  local processed_list = self.state.list
  for i = 1, #processed_list do
    local fold = processed_list[i]
    if fold.items and #fold.items > 0 and fold.items[1].status then
      local transformed_items = self:transform_entries_to_tree(fold.items, fold.metadata or {})
      fold.items = transformed_items
    end
  end

  generate_lines_recursive(processed_list, 0)

  for i = 1, #depth_0_item_counts do
    local depth_0_item_count = depth_0_item_counts[i]
    virtual_texts[#virtual_texts + 1] = {
      type = 'after',
      hl = 'GitSignsChange',
      lnum = depth_0_item_count.lnum,
      text = string.format('%s', depth_0_item_count.count),
    }
  end

  self.state.hls = hls
  self.state.virtual_texts = virtual_texts

  return foldable_list_shadow
end

function StatusListComponent:paint()
  if not self._element then return end

  local buffer = self._element.buffer

  local virtual_texts = self.state.virtual_texts
  for i = 1, #virtual_texts do
    local virtual_text = virtual_texts[i]
    if virtual_text.type == 'before' then
      buffer:place_extmark_text({
        text = virtual_text.text,
        hl = virtual_text.hl,
        row = virtual_text.lnum - 1,
        col = 0,
      })
    end
    if virtual_text.type == 'after' then
      buffer:place_extmark_text({
        text = virtual_text.text,
        hl = virtual_text.hl,
        row = virtual_text.lnum - 1,
        col = 0,
        pos = 'eol',
      })
    end
  end

  local hls = self.state.hls
  for i = 1, #hls do
    local hl_info = hls[i]
    local hl = hl_info.hl
    local lnum = hl_info.lnum
    local range = hl_info.range

    buffer:place_extmark_highlight({
      hl = hl,
      row = lnum - 1,
      col_range = {
        from = range.top,
        to = range.bot,
      },
    })
  end

  return self
end

function StatusListComponent:sync()
  if not self._element then return self end

  local buffer = self._element.buffer
  buffer:clear_extmarks()
  buffer:set_lines(self:generate_lines())

  self:paint()

  return self
end

function StatusListComponent:set_on_enter(callback)
  local loop = require('vgit.core.loop')
  self._on_enter_callback = loop.coroutine(callback)
  return self
end

function StatusListComponent:set_on_move(callback)
  local loop = require('vgit.core.loop')
  self._on_move_callback = loop.coroutine(callback)
  return self
end

function StatusListComponent:render()
  if not self._element then
    self._element = Element({
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
      },
    })
  end

  return LayoutSpec.view(self._element, {
    id = self.props.id or 'status_list',
    flex = self.props.flex or 1,
    width = self.props.width,
    height = self.props.height,
    focus = self.props.focus,
  })
end

function StatusListComponent:component_did_mount()
  -- Initial render
  self:sync()

  if self._element and self._element:is_valid() then
    self._element:set_keymap('n', '<enter>', function()
      local item = self:get_current_list_item()
      if not item then return end
      self:toggle_current_list_item()
      if self._on_enter_callback then self._on_enter_callback(item) end
    end, 'Enter item')

    if self.props.keymaps then self:setup_keymaps(self.props.keymaps, self.props.keymap_handlers) end

    local bufnr = self._element:get_bufnr()
    if bufnr then
      vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
        buffer = bufnr,
        callback = function()
          local item = self:get_current_list_item()
          if self._on_move_callback then self._on_move_callback(item) end
        end,
      })
    end
  end
end

function StatusListComponent:setup_keymaps(keymaps, handlers)
  if not self._element or not self._element:is_valid() then return end

  local function set_safe_keymap(mode, key_config, handler, desc)
    if not key_config or not key_config.key then return end
    self._element:set_keymap(mode, key_config.key, handler, key_config.desc or desc or '')
  end

  -- Set up keymaps with their handlers (automatically wrap in loop.coroutine)
  if keymaps.commit and handlers.commit then
    set_safe_keymap('n', keymaps.commit, loop.coroutine(handlers.commit), 'Commit')
  end
  if keymaps.buffer_reset and handlers.reset_file then
    set_safe_keymap('n', keymaps.buffer_reset, loop.coroutine(handlers.reset_file), 'Reset')
  end
  if keymaps.buffer_stage and handlers.stage_file then
    set_safe_keymap('n', keymaps.buffer_stage, loop.coroutine(handlers.stage_file), 'Stage')
  end
  if keymaps.buffer_unstage and handlers.unstage_file then
    set_safe_keymap('n', keymaps.buffer_unstage, loop.coroutine(handlers.unstage_file), 'Unstage')
  end
  if keymaps.stage_all and handlers.stage_all then
    set_safe_keymap('n', keymaps.stage_all, loop.coroutine(handlers.stage_all), 'Stage all')
  end
  if keymaps.unstage_all and handlers.unstage_all then
    set_safe_keymap('n', keymaps.unstage_all, loop.coroutine(handlers.unstage_all), 'Unstage all')
  end
  if keymaps.reset_all and handlers.reset_all then
    set_safe_keymap('n', keymaps.reset_all, loop.coroutine(handlers.reset_all), 'Reset all')
  end
end

function StatusListComponent:is_valid()
  return self._element and self._element:is_valid()
end

function StatusListComponent:focus()
  if self._element then self._element:focus() end
end

function StatusListComponent:destroy()
  self._element:destroy()
end

function StatusListComponent:unmount()
  if not self.mounted then return end

  self._element:unmount()
  self._element = nil

  Component.unmount(self)
end

return StatusListComponent
