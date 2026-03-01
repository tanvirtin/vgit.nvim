local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local utils = lazy('vgit.core.utils')
local event = lazy('vgit.core.event')
local icons = lazy('vgit.core.icons')
local Component = lazy('vgit.ui.Component')
local Element = lazy('vgit.ui.elements.Element')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local symbols_setting = lazy('vgit.settings.symbols')
local DepthTree = lazy('vgit.ui.components.TreeComponent.DepthTree')

local TreeComponent = Component:extend()

function TreeComponent:get_initial_state()
  return {
    list = {},
    title = '',
    hls = {},
    virtual_texts = {},
    shadow_list = {},
  }
end

function TreeComponent:constructor(props)
  local instance = Component.constructor(self, props)
  instance.state.list = props and props.list or {}
  instance.state.title = props and props.title or ''
  instance._element = nil
  instance._on_enter_callback = nil
  instance._on_move_callback = nil
  instance._keymaps_setup = false
  instance._rendering = false
  return instance
end

function TreeComponent:get_display_name(filename)
  if not filename then return filename end
  local path_parts = vim.split(filename, fs.sep)
  return path_parts[#path_parts] or filename
end

function TreeComponent:get_status_highlight(status)
  if not status:is_staged() and not status:is_unstaged() and not status:is_unmerged() then return 'GitLineNr' end

  if status:is_staged() then
    if status:has('A*') or status:has('C*') or status:has('R*') then return 'GitSignsAdd' end
    if status:has('D*') then return 'GitSignsDelete' end
    if status:has_either('MT') then return 'GitSignsChange' end
    return 'GitLineNr'
  end

  if status:is_unstaged() then
    if status:has('??') then return 'GitSignsAdd' end
    if status:has('*R') or status:has('*C') then return 'GitSignsAdd' end
    if status:has('*D') then return 'GitSignsDelete' end
    if status:has('*M') or status:has('*T') then return 'GitSignsChange' end
    return 'GitLineNr'
  end

  if status:is_unmerged() then return 'GitSignsChange' end

  return 'GitLineNr'
end

function TreeComponent:get_parent_folder(segmented_folders, current_index)
  local depth_tree = DepthTree()
  return depth_tree:get_parent_folder(segmented_folders, current_index)
end

function TreeComponent:normalize_entries(entries)
  local depth_tree = DepthTree()
  return depth_tree:normalize_entries(entries)
end

function TreeComponent:generate_tree(entries)
  local depth_tree = DepthTree()
  depth_tree:from_entries(entries)
  return depth_tree:value()
end

function TreeComponent:transform_entries_to_tree(entries)
  local depth_tree = DepthTree()
  depth_tree:from_entries(entries)
  depth_tree:sort()
  return depth_tree:value()
end

function TreeComponent:sort_tree(tree)
  local depth_tree = DepthTree()
  depth_tree:set_tree(tree)
  depth_tree:sort()
  return depth_tree:value()
end

function TreeComponent:create_node(entry)
  local depth_tree = DepthTree()
  local node = depth_tree:create_node(entry)

  if node.entry and node.entry.status and not node.items then
    local status = node.entry.status
    if status.old_filename then
      node.value =
        string.format('%s -> %s', self:get_display_name(status.old_filename), self:get_display_name(status.filename))
    else
      node.value = self:get_display_name(status.filename)
    end
  end

  return node
end

function TreeComponent:set_list(list)
  self:set_state({ list = list })
  return self
end

function TreeComponent:set_title(text)
  self:set_state({ title = text })
  return self
end

function TreeComponent:toggle_list_item(item)
  if item.items then item.open = not item.open end
  return self
end

function TreeComponent:is_fold(item)
  return item and item.items and #item.items > 0
end

function TreeComponent:get_list_item(lnum)
  return self.state.shadow_list[lnum]
end

function TreeComponent:each_list_item(callback)
  for lnum, item in pairs(self.state.shadow_list) do
    callback(item, lnum)
  end
end

function TreeComponent:find_list_item(callback)
  for lnum, item in pairs(self.state.shadow_list) do
    if callback(item, lnum) then return item, lnum end
  end
end

function TreeComponent:find_entry(callback)
  return self:find_list_item(function(node, lnum)
    local status = node.entry and node.entry.status or nil
    if not status then return false end
    local entry_type = node.entry.type
    return callback(status, entry_type, lnum) == true
  end)
end

function TreeComponent:each_entry(callback)
  self:each_list_item(function(node, lnum)
    local status = node.entry and node.entry.status or nil
    if not status then return false end
    local entry_type = node.entry.type
    callback(status, entry_type, lnum)
  end)
end

function TreeComponent:move_to(callback)
  local status, lnum = self:find_entry(callback)
  if not status then return end

  self:with_element(function(el)
    el:set_lnum(lnum)
  end)

  return status
end

function TreeComponent:get_current_list_item()
  return self:with_element(function(el)
    local lnum = el:get_lnum()
    return self:get_list_item(lnum)
  end)
end

function TreeComponent:get_selected_entry()
  local item = self:get_current_list_item()
  if item and item.entry then return item.entry end
  return nil
end

function TreeComponent:move(direction)
  return self:with_element(function(el)
    local lnum = el:get_lnum()
    local count = el:get_line_count()

    if direction == 'down' then lnum = lnum + 1 end
    if direction == 'up' then lnum = lnum - 1 end

    if lnum < 1 then
      lnum = count
    elseif lnum > count then
      lnum = 1
    end

    el:set_lnum(lnum)

    return self:get_list_item(lnum)
  end)
end

function TreeComponent:toggle_current_list_item()
  self:with_element(function(el)
    local lnum = el:get_lnum()
    local item = self:get_list_item(lnum)

    if item and item.open ~= nil then item.open = not item.open end

    if self._mounted then self:render() end
  end)
end

function TreeComponent:generate_lines()
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

      if item.entry and item.entry.status then
        local status = item.entry.status
        local filename = status.filename
        local filetype = status.filetype
        local icon, icon_hl = icons.get(filename, filetype)

        if status.old_filename then
          item.value = string.format(
            '%s -> %s',
            self:get_display_name(status.old_filename),
            self:get_display_name(status.filename)
          )
        end

        if icon then item.icon_before = {
          icon = icon,
          hl = icon_hl,
        } end

        item.virtual_text = {
          before = {
            text = status.value,
            hl = self:get_status_highlight(status),
          },
        }
      else
        item.icon_before = function(node)
          return { icon = node.open and '' or '' }
        end
      end

      current_lnum = current_lnum + 1

      if depth == 0 then
        depth_0_lnum = current_lnum
        item_count_for_depth_0 = 0
      end

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
      local depth_tree = DepthTree()
      fold.items = depth_tree:from_entries(fold.items):sort():value()
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

function TreeComponent:set_on_enter(callback)
  self._on_enter_callback = event.async(callback)
  return self
end

function TreeComponent:set_on_move(callback)
  self._on_move_callback = event.async(callback)
  return self
end

function TreeComponent:component_will_mount()
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
end

function TreeComponent:paint()
  self:with_element(function(el)
    local virtual_texts = self.state.virtual_texts
    for i = 1, #virtual_texts do
      local virtual_text = virtual_texts[i]
      if virtual_text.type == 'before' then
        el:place_extmark_text({
          text = virtual_text.text,
          hl = virtual_text.hl,
          row = virtual_text.lnum - 1,
          col = 0,
        })
      end
      if virtual_text.type == 'after' then
        el:place_extmark_text({
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

      el:place_extmark_highlight({
        hl = hl,
        row = lnum - 1,
        col_range = {
          from = range.top,
          to = range.bot,
        },
      })
    end
  end)

  return self
end

function TreeComponent:render()
  self:with_element(function(el)
    self._rendering = true
    el:clear_extmarks()
    el:set_lines(self:generate_lines())
    self._rendering = false
    self:paint()
  end)
end

function TreeComponent:get_layout_spec()
  return LayoutSpec.view(self._element, {
    id = self.props.id or 'status_list',
    flex = self.props.flex or 1,
    width = self.props.width,
    height = self.props.height,
    focus = self.props.focus,
  })
end

function TreeComponent:component_did_mount()
  self:render()

  self:with_element(function(el)
    if not self._keymaps_setup then
      el:set_keymap('n', '<enter>', function()
        local item = self:get_current_list_item()
        if not item then return end
        self:toggle_current_list_item()
        if self._on_enter_callback then self._on_enter_callback(item) end
      end, 'Enter item')

      if self.props.keymaps then self:setup_keymaps(self.props.keymaps, self.props.keymap_handlers) end

      local buf = el:get_buffer()
      if buf then
        buf:on('CursorMoved', function()
          if self._rendering then return end
          local item = self:get_current_list_item()
          if self._on_move_callback then self._on_move_callback(item) end
        end)
      end

      self._keymaps_setup = true
    end
  end)
end

function TreeComponent:setup_keymaps(keymaps, handlers)
  self:with_element(function(el)
    if not keymaps or not handlers then return end

    local function set_safe_keymap(mode, key_config, handler, desc)
      if not key_config then return end

      local key = nil
      local key_desc = desc or ''

      if type(key_config) == 'string' then
        key = key_config
      elseif type(key_config) == 'table' then
        key = key_config.key
        key_desc = key_config.desc or desc or ''
      end

      if not key then return end

      el:set_keymap(mode, key, handler, key_desc)
    end

    if keymaps.commit and handlers.commit then set_safe_keymap('n', keymaps.commit, handlers.commit, 'Commit') end
    if keymaps.buffer_reset and handlers.reset_file then
      set_safe_keymap('n', keymaps.buffer_reset, handlers.reset_file, 'Reset')
    end
    if keymaps.buffer_stage and handlers.stage_file then
      set_safe_keymap('n', keymaps.buffer_stage, handlers.stage_file, 'Stage')
    end
    if keymaps.buffer_unstage and handlers.unstage_file then
      set_safe_keymap('n', keymaps.buffer_unstage, handlers.unstage_file, 'Unstage')
    end
    if keymaps.stage_all and handlers.stage_all then
      set_safe_keymap('n', keymaps.stage_all, handlers.stage_all, 'Stage all')
    end
    if keymaps.unstage_all and handlers.unstage_all then
      set_safe_keymap('n', keymaps.unstage_all, handlers.unstage_all, 'Unstage all')
    end
    if keymaps.reset_all and handlers.reset_all then
      set_safe_keymap('n', keymaps.reset_all, handlers.reset_all, 'Reset all')
    end
  end)
end

function TreeComponent:get_lnum()
  return self:with_element(function(el)
    return el:get_lnum()
  end) or 1
end

function TreeComponent:set_lnum(lnum)
  self:with_element(function(el)
    el:set_lnum(lnum)
  end)
  return self
end

function TreeComponent:get_line_count()
  return self:with_element(function(el)
    return el:get_line_count()
  end) or 0
end

function TreeComponent:is_valid()
  return self:with_element(function()
    return true
  end) or false
end

function TreeComponent:focus()
  self:with_element(function(el) el:focus() end)
end

function TreeComponent:unmount()
  if not self._mounted then return end

  self._element:unmount()
  self._element = nil

  Component.unmount(self)
end

return TreeComponent
