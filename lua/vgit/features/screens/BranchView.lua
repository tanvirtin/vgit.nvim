local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local SearchComponent = lazy('vgit.ui.components.SearchComponent')

local BranchView = View:extend()

function BranchView:constructor()
  local instance = View.constructor(self)
  instance._search_component = nil
  return instance
end

function BranchView:_build_items(branches, current_branch)
  local items = {}

  for i = 1, #branches do
    local branch = branches[i]
    local is_current = branch.name == current_branch
    items[#items + 1] = {
      label = branch.name,
      icon = is_current and '' or nil,
      icon_hl = is_current and 'GitSignsAdd' or nil,
      description = is_current and '(current)' or nil,
      value = branch.name,
    }
  end

  return items
end

function BranchView:create(data)
  if not data then return false end
  if type(data) ~= 'table' then return false end
  if not data.branches or #data.branches == 0 then return false end

  local items = self:_build_items(data.branches, data.current_branch)

  self._search_component = SearchComponent({
    items = items,
    width = '40vw',
    max_height = 10,
    page_size = 25,
    placeholder = 'No branches found',
    on_select = function(value)
      self:_on_select(value)
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

function BranchView:destroy()
  self._search_component = nil
  View.destroy(self)
end

function BranchView:_on_select(value)
  self:destroy()

  if not value then return end

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local refs = repo:refs()
  local _, err = refs:checkout(value)

  if err then
    console.error(err)
    return
  end

  console.info('Switched to branch ' .. value)
end

function BranchView:_on_no_match(query)
  if not query or query == '' then return end

  self:destroy()

  local decision = console.input(string.format('Branch \'%s\' does not exist. Create it? (y/N) ', query))
  if not decision then return end

  decision = decision:lower()
  if decision ~= 'y' and decision ~= 'yes' then return end

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local refs = repo:refs()
  local _, err = refs:checkout_new_branch(query)

  if err then
    console.error(err)
    return
  end

  console.info('Created and switched to branch ' .. query)
end

return BranchView
