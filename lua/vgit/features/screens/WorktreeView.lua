local lazy = require('vgit.core.lazy')

local Layout = lazy('vgit.ui.Layout')
local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local console = lazy('vgit.core.console')
local git_repo = lazy('vgit.git.git_repo')
local repository = lazy('vgit.git.repository')
local git_worktree = lazy('vgit.git.git_worktree')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local SearchComponent = lazy('vgit.ui.components.SearchComponent')

local WorktreeView = Object:extend()

WorktreeView.DEBOUNCE_MS = 200

function WorktreeView:constructor()
  return {
    _data = nil,
    _repo = nil,
    _search_component = nil,
    _component_manager = nil,
    _debounce_cleanups = {},
    _destroyed = false,
  }
end

function WorktreeView:_is_current_worktree(worktree)
  if not self._repo then return false end
  local repo_path = self._repo:get_path()
  if not repo_path or not worktree.path then return false end
  return vim.fn.resolve(repo_path) == vim.fn.resolve(worktree.path)
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
      value = { worktree = wt },
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
  vim.cmd('cd ' .. vim.fn.fnameescape(worktree.path))
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

  local decision = console.input(string.format('Create worktree at \'%s\'? (y/N) ', query))
  if not decision then return end

  decision = decision:lower()
  if decision ~= 'y' and decision ~= 'yes' then return end

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
    if item and item.value and item.value.worktree then return item.value.worktree end
  end
  return nil
end

function WorktreeView:_make_debounced(fn)
  local debounced, cleanup = event.debounce_async(fn, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, cleanup)
  return debounced
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
      if value and value.worktree then self:_switch_to_worktree(value.worktree) end
    end,
    on_no_match = function(query)
      self:_on_no_match(query)
    end,
    on_close = function()
      self:destroy()
    end,
  })

  self._component_manager = ComponentManager()
  self._component_manager:render(Layout.popup(self._search_component))

  return true
end

function WorktreeView:is_destroyed()
  return self._destroyed
end

function WorktreeView:destroy()
  if self._destroyed then return end
  self._destroyed = true

  for _, cleanup in ipairs(self._debounce_cleanups) do
    cleanup()
  end
  self._debounce_cleanups = {}

  if self._component_manager then
    self._component_manager:destroy()
    self._component_manager = nil
  end

  self._search_component = nil
end

return WorktreeView
