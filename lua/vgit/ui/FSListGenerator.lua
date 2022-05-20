local utils = require('vgit.core.utils')
local icons = require('vgit.core.icons')
local Object = require('vgit.core.Object')

--[[
  The foldable list component draws itself using a configuration table.
  This means we can create a file tree config generator that given a
  generic data shape can generate a tree blueprint out of it.
--]]

local FSListGenerator = Object:extend()

function FSListGenerator:constructor(entries)
  return {
    tree = {},
    seperator = '/',
    entries = entries,
    normalized_paths = {},
    normalized_paths_sorted_by_depth = {},
  }
end

function FSListGenerator:get_parent_folder(segmented_folders, current_index)
  local acc = ''
  local count = 1

  for i = 1, #segmented_folders do
    local foldername = segmented_folders[i]

    if i == current_index then
      return acc, count
    end

    count = count + 1
    acc = string.format('%s%s%s', acc, self.seperator, foldername)
  end

  return acc, count
end

function FSListGenerator:normalize_filename(filename, id, file)
  local normalized_paths = self.normalized_paths
  -- Split the filename by it's seperator and create a list of all folders.
  local segmented_folders = vim.split(filename, self.seperator)

  -- Loop over each segment and create paths by concanating 1..i items in
  -- the segmented folder, storing all the necessary metadata in the process.
  for i = 1, #segmented_folders do
    local parent_folder_name, depth = self:get_parent_folder(
      segmented_folders,
      i
    )
    local current_folder_name = segmented_folders[i]
    local path = string.format(
      '%s%s%s',
      parent_folder_name,
      self.seperator,
      current_folder_name
    )
    -- normalized_paths will never contain duplicate entries, since a path will always be unique!
    -- When we split the path by seperator, the number of seperators for
    -- a given position (i) is the depth of the path in the file tree.
    -- Note: two folders can have the same depth even if they don't live in the same folder.
    normalized_paths[path] = {
      id = id,
      depth = depth,
      parent = parent_folder_name,
      current = current_folder_name,
      path = path,
      file = i == #segmented_folders and file or nil,
    }
  end

  return self
end

function FSListGenerator:sort_normalized_paths_by_depth()
  local normalized_paths = self.normalized_paths
  local filter_by_depth = {}

  -- Using the paths we normalized and storing them in a key-value table called normalized_paths
  -- I am now creating a list, which will have a size of total depth in the tree.
  -- Each item in the list will be another list of paths, e.g:
  -- { [1] = { Path{}, Path{} }, [2] = { Path{} }, [3] = { Path{}, Path{} } }
  for _, path in pairs(normalized_paths) do
    local depth_list = filter_by_depth[path.depth]

    if not depth_list then
      filter_by_depth[path.depth] = { path }
    else
      depth_list[#depth_list + 1] = path
    end
  end

  self.normalized_paths_sorted_by_depth = filter_by_depth

  return self
end

function FSListGenerator:create_node(path)
  local metadata = self.metadata

  if path.file then
    local id = path.id
    local file = path.file
    local filename = file.filename
    local filetype = file.filetype
    local icon, icon_hl = icons.get(filename, filetype)

    local list_entry = {
      id = id,
      path = path,
      metadata = metadata,
      value = path.current,
    }

    if icon then
      list_entry.icon_before = {
        icon = icon,
        hl = icon_hl,
      }
    end

    return list_entry
  end

  return {
    items = {},
    open = true,
    path = path,
    show_count = false,
    metadata = metadata,
    value = path.current,
    icon_before = function(item)
      return {
        icon = item.open and '' or '',
      }
    end,
  }
end

-- Finds the parent from the tree for a given path
-- (path obj will contain it's parent path string).
function FSListGenerator:find_parent(path)
  local function _find(tree)
    if not tree then
      return nil
    end

    for i = 1, #tree do
      local item = tree[i]

      if item.path.path == path.parent then
        return item.items
      else
        local found = _find(item.items)

        if found then
          return found
        end
      end
    end
  end

  return _find(self.tree)
end

function FSListGenerator:sort()
  local function sort_items(list)
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

    return utils.list.merge(folders, files)
  end

  local function _sort(tree)
    for i = 1, #tree do
      local item = tree[i]

      if item.items then
        item.items = sort_items(item.items)
        _sort(item.items)
      end
    end
  end

  self.tree = sort_items(self.tree)

  _sort(self.tree)

  return self
end

function FSListGenerator:generate_tree()
  local normalized_paths_sorted_by_depth = self.normalized_paths_sorted_by_depth

  for i = 1, #normalized_paths_sorted_by_depth do
    -- As we now, each element in the normalized_paths_sorted_by_depth is a list of paths.
    local paths = normalized_paths_sorted_by_depth[i]

    for j = 1, #paths do
      local path = paths[j]
      -- Given a path self:find_parent will find the parent list from the tree.
      -- NOTE: path is an object which contains metadata on it's own pathname, parent pathname, etc.
      -- If we are in the root depth, self:find_parent(path) will return nil, so we just point to the root list.
      local parent = self:find_parent(path) or self.tree

      -- We create a node which can be a file item entry or a folder item entry to the parent list we found.
      parent[#parent + 1] = self:create_node(path)
    end
  end

  return self
end

function FSListGenerator:generate(metadata)
  self.metadata = metadata
  local entries = self.entries

  for i = 1, #entries do
    local entry = entries[i]
    local id = entry.id
    local file = entry.file
    local filename = file.filename

    self:normalize_filename(filename, id, file)
  end

  self:sort_normalized_paths_by_depth():generate_tree():sort()

  return self.tree
end

return FSListGenerator
