local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local display_service = lazy('vgit.ui.display_service')

local branch_command = {}

branch_command.execute = event.async(function()
  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local refs = repo:refs()

  local branches, branches_err = refs:branches()
  if branches_err then
    console.error(branches_err)
    return
  end

  if not branches or #branches == 0 then
    console.info('No branches found')
    return
  end

  local current_branch = refs:current_branch()

  table.sort(branches, function(a, b)
    local a_current = a.name == current_branch
    local b_current = b.name == current_branch
    if a_current ~= b_current then return a_current end
    return a.name < b.name
  end)

  display_service.show_branch({
    branches = branches,
    current_branch = current_branch,
  })
end)

return branch_command
