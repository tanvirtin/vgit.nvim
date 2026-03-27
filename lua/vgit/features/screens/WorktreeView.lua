local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local fs = lazy('vgit.core.fs')
local console = lazy('vgit.core.console')
local git_repo = lazy('vgit.git.git_repo')
local repository = lazy('vgit.git.repository')
local git_worktree = lazy('vgit.git.git_worktree')
local SearchComponent = lazy('vgit.ui.components.SearchComponent')

local WorktreeView = View:extend()

WorktreeView.DEBOUNCE_MS = 200

function WorktreeView:constructor()
  local instance = View.constructor(self)
  instance._data = nil
  instance._repo = nil
  instance._search_component = nil
  return instance
end

function WorktreeView:_is_current_worktree(worktree)
  if not self._repo then return false end
  local repo_path = self._repo:get_path()
  if not repo_path or not worktree.path then return false end
  return fs.resolve(repo_path) == fs.resolve(worktree.path)
end

function WorktreeView:_build_items(worktrees)
  local items = {}
  for _, wt in ipairs(worktrees) do
    local is_current = self:_is_current_worktree(wt)
    local branch_display = wt.branch or (wt.detached and '(detached)') or '(bare)'
    local path_display = wt.path or ''

    items[#items + 1] = {
      label = branch_display .. '  ' .. path_display,
      icon = is_current and '' or nil,
      icon_hl = is_current and 'GitSignsAdd' or nil,
      description = is_current and '(current)' or (wt.locked and '(locked)' or nil),
      value = { type = 'worktree', data = wt },
    }
  end
  return items
end

function WorktreeView:_switch_to_worktree(worktree)
  if not worktree or not worktree.path then return end
  if self:_is_current_worktree(worktree) then
    console.info('Already in this worktree')
    return
  end
  self:destroy()
  repository.invalidate()
  git_repo.clear_cache()
  fs.chdir(worktree.path)
  console.info('Switched to worktree: ' .. worktree.path)
end

function WorktreeView:_refresh_worktree_list()
  local repo = self._repo
  if not repo then return end

  local worktrees, err = git_worktree.list(repo:get_path())

  if err then
    console.debug.error(string.format('[WorktreeView] list failed: %s', err[1] or tostring(err)))
    return
  end

  if not worktrees or #worktrees == 0 then
    self:destroy()
    return
  end

  local items = self:_build_items(worktrees)

  if self._search_component and self._search_component:is_valid() then self._search_component:set_items(items) end
end

function WorktreeView:_on_no_match(query)
  if not query or query == '' then return end

  self:destroy()

  if not self:_confirm(string.format('Create worktree at \'%s\'? (y/N) ', query)) then return end

  local repo = self._repo
  if not repo then return end

  local _, err = repo:worktree_add(query)
  if err then
    console.error(err[1] or tostring(err))
    return
  end

  console.info('Worktree created: ' .. query)
end

function WorktreeView:_get_current_worktree()
  if self._search_component and self._search_component:is_valid() then
    local item = self._search_component:get_selected_item()
    if item and item.value and item.value.data then return item.value.data end
  end
  return nil
end

function WorktreeView:create(data)
  if not data then return false end
  if type(data) ~= 'table' then return false end
  if not data.worktrees or type(data.worktrees) ~= 'table' or #data.worktrees == 0 then return false end

  self._data = data
  self._repo = data.repo

  local items = self:_build_items(data.worktrees)

  self._search_component = SearchComponent({
    items = items,
    width = '40vw',
    max_height = 10,
    page_size = 25,
    placeholder = 'No worktrees found',
    on_select = function(value)
      if value and value.data then self:_switch_to_worktree(value.data) end
    end,
    on_no_match = function(query)
      self:_on_no_match(query)
    end,
    on_close = function()
      self:destroy()
    end,
  })

  self:_render({
    component = self._search_component,
    mode = 'popup',
  })

  return true
end

return WorktreeView
