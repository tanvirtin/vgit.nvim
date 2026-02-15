local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local scene_setting = lazy('vgit.settings.scene')
local FileDiffView = lazy('vgit.features.screens.FileDiffView')
local ProjectDiffView = lazy('vgit.features.screens.ProjectDiffView')
local HunkLens = lazy('vgit.features.lenses.HunkLens')
local BlameLens = lazy('vgit.features.lenses.BlameLens')
local StatusDiffView = lazy('vgit.features.screens.StatusDiffView')
local BranchView = lazy('vgit.features.screens.BranchView')

local active_view = nil
local _events_registered = false
local display_service = {}

function display_service.register_events()
  if _events_registered then return end
  _events_registered = true

  event.custom_on('VGitChange', function()
    if active_view and active_view.on_git_change then
      active_view:on_git_change()
      -- View may have destroyed itself (e.g. no more changes after commit)
      if active_view and active_view.destroyed then active_view = nil end
    end
  end)
end

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
    view = FileDiffView()
  elseif data.type == 'files' then
    -- Check if there are any changes to display
    if not data.entries or #data.entries == 0 then
      console.info('No changes to display')
      return
    end
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

  local view = StatusDiffView()
  local success = view:create(data)
  if not success then
    console.error('Failed to create status view')
    return
  end
  active_view = view
end)

display_service.show_branch = event.async(function(data)
  if not data then
    console.error('No branch data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  event.await()

  local view = BranchView()
  local success = view:create(data)
  if not success then
    console.error('Failed to create branch view')
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

function display_service.get_active_view()
  return active_view
end

function display_service.reset()
  if active_view and active_view.destroy then
    active_view:destroy()
  end
  active_view = nil
  _events_registered = false
end

return display_service
