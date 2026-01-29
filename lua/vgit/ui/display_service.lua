local event = require('vgit.core.event')
local console = require('vgit.core.console')
local scene_setting = require('vgit.settings.scene')

local active_view = nil
local display_service = {}

event.custom_on('VGitChange', function()
  if active_view and active_view.on_git_change then active_view:on_git_change() end
end)

display_service.show_diff = event.async(function(data)
  if not data then
    console.error('No data provided')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  if data.type == 'empty' then
    console.info(data.message or 'No changes')
    return
  end

  event.await()

  local view
  if data.type == 'file' then
    local FileDiffView = require('vgit.features.screens.FileDiffView')
    view = FileDiffView()
  elseif data.type == 'files' then
    -- Check if there are any changes to display
    if not data.entries or #data.entries == 0 then
      console.info('No changes to display')
      return
    end
    local ProjectDiffView = require('vgit.features.screens.ProjectDiffView')
    view = ProjectDiffView()
  else
    console.error('Unknown data type: ' .. tostring(data.type))
    return
  end

  local success = view:create(data)
  if not success then
    console.error('Failed to create diff view')
    return
  end
  active_view = view
end)

display_service.show_hunk = event.async(function(data)
  if not data then
    console.error('No hunk data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  event.await()

  local HunkLens = require('vgit.features.lenses.HunkLens')
  local lens = HunkLens()
  lens:create(data)

  active_view = lens
end)

display_service.show_blame = event.async(function(data)
  if not data then
    console.error('No blame data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  event.await()
  event.await()

  local BlameLens = require('vgit.features.lenses.BlameLens')
  local lens = BlameLens()
  lens:create(data)

  active_view = lens
end)

display_service.show_status = event.async(function(data)
  if not data then
    console.error('No status data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  if not data.entries or #data.entries == 0 then
    console.info('No changes to display')
    return
  end

  event.await()

  local StatusDiffView = require('vgit.features.screens.StatusDiffView')
  local view = StatusDiffView()
  local success = view:create(data)
  if not success then
    console.error('Failed to create status view')
    return
  end
  active_view = view
end)

function display_service.toggle_diff_preference()
  local current = scene_setting:get('diff_preference')
  local new_pref = current == 'unified' and 'split' or 'unified'
  scene_setting:set('diff_preference', new_pref)
end

function display_service.help()
  if active_view and active_view.help then
    active_view:help()
    return true
  end
  return false
end

return display_service
