local lazy = require('vgit.core.lazy')
local fs = lazy('vgit.core.fs')
local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')

local DepthTree = Object:extend()

function DepthTree:constructor()
  return {
    _tree = {},
  }
end

function DepthTree:value()
  return self._tree
end

function DepthTree:get_parent_folder(segmented_folders, current_index)
  local folder = ''
  local depth = 1
  local separator = fs.sep

  for i = 1, #segmented_folders do
    if i == current_index then return folder, depth end

    local foldername = segmented_folders[i]

    depth = depth + 1
    folder = string.format('%s%s%s', folder, separator, foldername)
  end

  return folder, depth
end

function DepthTree:create_file_node(entry)
  return {
    id = entry.id,
    entry = entry,
    value = entry.current,
  }
end

function DepthTree:create_folder_node(entry)
  return {
    items = {},
    open = true,
    entry = entry,
    value = entry.current or 'Unknown',
  }
end

function DepthTree:create_node(entry)
  if entry.status then return self:create_file_node(entry) end
  return self:create_folder_node(entry)
end

function DepthTree:find_parent_node(entry)
  local function _find(tree)
    if not tree then return nil end

    for i = 1, #tree do
      local node = tree[i]

      if node.entry.path == entry.parent then return node end

      local found = _find(node.items)
      if found then return found end
    end
  end

  return _find(self._tree)
end

function DepthTree:sort()
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

  self._tree = sort_tree(self._tree)
  _sort_tree(self._tree)

  return self
end

function DepthTree:from_entries(entries)
  local separator = fs.sep
  local normalized_entries = {}

  for i = 1, #entries do
    local entry = entries[i]

    local id = entry.id
    local status = entry.status
    local entry_type = entry.type
    local filename = status.filename

    local segmented_folders = vim.split(filename, separator)

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

  for i = 1, #normalized_entries_by_depth do
    local entries_at_depth = normalized_entries_by_depth[i]
    for j = 1, #entries_at_depth do
      local entry = entries_at_depth[j]
      local parent_node = self:find_parent_node(entry)

      if parent_node then
        parent_node.items[#parent_node.items + 1] = self:create_node(entry)
      else
        self._tree[#self._tree + 1] = self:create_node(entry)
      end
    end
  end

  return self
end

return DepthTree
