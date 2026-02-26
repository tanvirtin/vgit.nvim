local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local display_service = lazy('vgit.ui.display_service')

local log_command = {}

log_command.execute = event.async(function()
  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local history = repo:history({ count = 100 })

  local commits, commits_err = history:commits()
  if commits_err then
    console.error(commits_err)
    return
  end

  if not commits or #commits == 0 then
    console.info('No commits found')
    return
  end

  display_service.show_log({
    commits = commits,
    history = history,
    repo_path = repo:get_path(),
  })
end)

return log_command
