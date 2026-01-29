local event = require('vgit.core.event')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')
local display_service = require('vgit.ui.display_service')
local scene_setting = require('vgit.settings.scene')

local status_command = {}

status_command.execute = event.async(function()
  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  event.await()

  local data, err = repo:status({})

  if err then
    console.error(err)
    return
  end

  if not data or not data.entries or #data.entries == 0 then
    console.info('No changes to display')
    return
  end

  local layout_type = scene_setting:get('diff_preference') or 'unified'

  local transformed_data = {
    type = 'status',
    entries = data.entries,
    layout_type = layout_type,
  }

  display_service.show_status(transformed_data)
end)

return status_command
