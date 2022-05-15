local utils = require('vgit.core.utils')
local icons = require('vgit.core.icons')
local Object = require('vgit.core.Object')

local FSListGenerator = Object:extend()

function FSListGenerator:constructor(entries)
  return {
    seperator = '/',
    entries = entries,
    paths = {},
    tree = {},
    tree_by_depth = {},
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
    acc = string.format('%s/%s', acc, foldername)
  end

  return acc, count
end

function FSListGenerator:generate_paths(id, filename, file)
  local paths = self.paths
  local segmented_folders = vim.split(filename, self.seperator)

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
    paths[path] = {
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

function FSListGenerator:generate_tree_by_depth()
  local paths = self.paths

  local filter_by_depth = {}

  for _, path in pairs(paths) do
    local depth_list = filter_by_depth[path.depth]

    if not depth_list then
      filter_by_depth[path.depth] = { path }
    else
      depth_list[#depth_list + 1] = path
    end
  end

  self.tree_by_depth = filter_by_depth

  return self
end

function FSListGenerator:create_node(path)
  if path.file then
    local id = path.id
    local file = path.file
    local filename = file.filename
    local filetype = file.filetype
    local icon, icon_hl = icons.get(filename, filetype)

    local list_entry = {
      id = id,
      value = path.current,
      path = path,
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
    open = true,
    value = path.current,
    items = {},
    path = path,
  }
end

function FSListGenerator:find(path)
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

function FSListGenerator:debug()
  local function _print(tree)
    for i = 1, #tree do
      local item = tree[i]

      if item.items then
        print(item.value)
        _print(item.items)
      else
        print(item.value)
      end
    end
  end

  _print(self.tree)

  return self
end

function FSListGenerator:generate_tree()
  for i = 1, #self.tree_by_depth do
    local level_paths = self.tree_by_depth[i]

    for j = 1, #level_paths do
      local path = level_paths[j]
      local parent = self:find(path) or self.tree

      parent[#parent + 1] = self:create_node(path)
    end
  end

  return self
end

function FSListGenerator:generate()
  local entries = self.entries

  for i = 1, #entries do
    local entry = entries[i]
    local id = entry.id
    local file = entry.file
    local filename = file.filename

    self:generate_paths(id, filename, file)
  end

  self:generate_tree_by_depth():generate_tree():sort()

  return self.tree
end

return FSListGenerator
