local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local HunkLens = lazy('vgit.features.lenses.HunkLens')
local BlameLens = lazy('vgit.features.lenses.BlameLens')
local BlameView = lazy('vgit.features.screens.BlameView')
local StashView = lazy('vgit.features.screens.StashView')
local BranchView = lazy('vgit.features.screens.BranchView')
local FileDiffView = lazy('vgit.features.screens.FileDiffView')
local StatusDiffView = lazy('vgit.features.screens.StatusDiffView')
local ProjectDiffView = lazy('vgit.features.screens.ProjectDiffView')
local WorktreeView = lazy('vgit.features.screens.WorktreeView')
local CommitPickerView = lazy('vgit.features.screens.CommitPickerView')

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
      if active_view and active_view:is_destroyed() then active_view = nil end
    end
  end)

  event.custom_on('VGitDirChanged', function()
    if active_view and active_view.destroy then active_view:destroy() end
    active_view = nil
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
  if not success then return end
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

display_service.show_stash = event.async(function(data)
  if not data then
    console.error('No stash data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  event.await()

  local view = StashView()
  local success = view:create(data)
  if not success then
    console.error('Failed to create stash view')
    return
  end
  active_view = view
end)

display_service.show_worktree = event.async(function(data)
  if not data then
    console.error('No worktree data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  event.await()

  local view = WorktreeView()
  local success = view:create(data)
  if not success then
    console.error('Failed to create worktree view')
    return
  end
  active_view = view
end)

display_service.show_log = event.async(function(data)
  if not data then
    console.error('No log data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  event.await()

  local view = CommitPickerView()
  local success = view:create(data)
  if not success then
    console.error('Failed to create log view')
    return
  end
  active_view = view
end)

display_service.show_blame_view = event.async(function(data)
  if not data then
    console.error('No blame view data')
    return
  end

  if active_view and active_view.destroy then
    active_view:destroy()
    active_view = nil
  end

  event.await()

  local view = BlameView()
  local success = view:create(data)
  if not success then
    console.error('Failed to create blame view')
    return
  end
  active_view = view
end)

display_service.show_blame_view_for_file = event.async(function(filename)
  if not filename then return end

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local filetype = fs.detect_filetype(filename)

  local blames, blame_err = repo:blame_list(filename)
  if blame_err or not blames or #blames == 0 then
    console.info('No blame information available for this file')
    return
  end

  local lines, lines_err = repo:file_lines(filename, 'HEAD')
  if lines_err or not lines then lines = {} end

  display_service.show_blame_view({
    filename = filename,
    filetype = filetype,
    reponame = repo:get_path(),
    blames = blames,
    lines = lines,
  })
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
  if active_view and active_view.destroy then active_view:destroy() end
  active_view = nil
  _events_registered = false
end

function display_service.cleanup()
  display_service.reset()
end

return display_service
