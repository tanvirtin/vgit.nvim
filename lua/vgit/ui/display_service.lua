local loop = require('vgit.core.loop')
local console = require('vgit.core.console')
local scene_setting = require('vgit.settings.scene')

local display_service = {}
local active_view = nil

display_service.show_diff = loop.coroutine(function(data)
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

  loop.free_textlock()

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

  view:create(data)
  active_view = view
end)

display_service.show_hunk = loop.coroutine(function(data)
  if not data then
    console.error('No hunk data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  loop.suspend_textlock()

  local HunkLens = require('vgit.features.lenses.HunkLens')
  local lens = HunkLens()
  lens:create(data)

  active_view = lens
end)

display_service.show_blame = loop.coroutine(function(data)
  if not data then
    console.error('No blame data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  loop.suspend_textlock()
  loop.free_textlock()

  local BlameLens = require('vgit.features.lenses.BlameLens')
  local lens = BlameLens()
  lens:create(data)

  active_view = lens
end)

function display_service.dispatch_action(action)
  -- Dispatch actions to active views
  if not active_view then return false end

  if action == 'hunk_up' and active_view.hunk_up then
    active_view:hunk_up()
    return true
  elseif action == 'hunk_down' and active_view.hunk_down then
    active_view:hunk_down()
    return true
  end

  return false
end

function display_service.toggle_diff_preference()
  local current = scene_setting:get('diff_preference')
  local new_pref = current == 'unified' and 'split' or 'unified'
  scene_setting:set('diff_preference', new_pref)

  if active_view and active_view.refresh then active_view:refresh() end
end

function display_service.help()
  if active_view and active_view.help then
    active_view:help()
    return true
  end
  return false
end

return display_service
