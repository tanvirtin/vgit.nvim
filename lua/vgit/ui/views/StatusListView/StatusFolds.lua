local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local icons = require('vgit.core.icons')
local Object = require('vgit.core.Object')

--[[
  The foldable list component draws itself using a configuration table.
  This means we can create a file tree config generator that given a
  generic data shape can generate a tree blueprint out of it.
--]]

local StatusFolds = Object:extend()

function StatusFolds:constructor(metadata)
  return {
    tree = {},
    seperator = fs.sep,
    metadata = metadata,
  }
end

function StatusFolds:get_parent_folder(segmented_folders, current_index)
  local acc = ''
  local count = 1

  for i = 1, #segmented_folders do
    if i == current_index then return acc, count end

    local foldername = segmented_folders[i]

    count = count + 1
    acc = string.format('%s%s%s', acc, self.seperator, foldername)
  end

  return acc, count
end

function StatusFolds:derive_status_hl(status)
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

function StatusFolds:create_node(entry)
  if entry.status then
    local id = entry.id
    local status = entry.status
    local filename = status.filename
    local filetype = status.filetype
    local icon, icon_hl = icons.get(filename, filetype)

    local node = {
      id = id,
      entry = entry,
      value = entry.current,
      metadata = self.metadata,
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
    value = entry.current,
    metadata = self.metadata,
    icon_before = function(item)
      return { icon = item.open and '' or '' }
    end,
  }
end

-- Finds the parent from the tree for a given path
-- (path obj will contain it's parent path string).
function StatusFolds:find_parent(entry)
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

  return _find(self.tree)
end

function StatusFolds:normalize_entries(entries)
  local normalized_entries = {}

  for i = 1, #entries do
    local entry = entries[i]

    local id = entry.id
    local status = entry.status
    local entry_type = entry.type
    local filename = status.filename

    -- Split the filename by it's seperator and create a list of all folders.
    local segmented_folders = vim.split(filename, self.seperator)

    -- Loop over each segment and create paths by concanating 1..i items in
    -- the segmented folder, storing all the necessary metadata in the process.
    for j = 1, #segmented_folders do
      local parent_folder_name, depth = self:get_parent_folder(segmented_folders, j)
      local current_folder_name = segmented_folders[j]
      local path = string.format('%s%s%s', parent_folder_name, self.seperator, current_folder_name)
      -- normalized_entries will never contain duplicate entries, since a path will always be unique!
      -- When we split the path by seperator, the number of seperators for
      -- a given position (i) is the depth of the path in the file tree.
      -- Note: two folders can have the same depth even if they don't live in the same folder.
      normalized_entries[path] = {
        id = id,
        path = path,
        depth = depth,
        type = entry_type,
        metadata = self.metadata,
        parent = parent_folder_name,
        current = current_folder_name,
        status = j == #segmented_folders and status or nil,
      }
    end
  end

  local normalized_entries_by_depth = {}

  -- Using the entries we normalized and storing them in a key-value table called normalized_entries
  -- I am now creating a list, which will have a size of total depth in the tree.
  -- Each item in the list will be another list of paths, e.g:
  -- { [1] = { Entry{}, Entry{} }, [2] = { Entry{} }, [3] = { Entry{}, Entry{} } }
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

function StatusFolds:generate_tree(normalized_entries)
  for i = 1, #normalized_entries do
    -- As we now, each element in the normalized_entries is a list of entries.
    local entries = normalized_entries[i]
    for j = 1, #entries do
      local entry = entries[j]
      -- Given a entry self:find_parent will find the parent list from the tree.
      -- NOTE: entry is an object which contains metadata on it's own path, parent path, etc.
      -- If we are in the root depth, self:find_parent(entry) will return nil, so we just point to the root list.
      local parent = self:find_parent(entry) or self.tree
      -- We create a node which can be a file entry or a folder entry to the parent list we found.
      parent[#parent + 1] = self:create_node(entry)
    end
  end
end

function StatusFolds:sort_tree()
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

  self.tree = sort_tree(self.tree)
  _sort_tree(self.tree)
end

function StatusFolds:generate(entries)
  local normalized_entries = self:normalize_entries(entries)

  self:generate_tree(normalized_entries)
  self:sort_tree()

  return self.tree
end

return StatusFolds
