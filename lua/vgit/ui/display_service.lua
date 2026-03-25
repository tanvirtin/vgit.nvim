local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local HunkLensView = lazy('vgit.features.lenses.HunkLensView')
local BlameLensView = lazy('vgit.features.lenses.BlameLensView')
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
local _event_cleanups = {}
local _showing = false
local display_service = {}

function display_service.register_events()
  if _events_registered then return end
  _events_registered = true

  _event_cleanups[#_event_cleanups + 1] = event.custom_on('VGitChange', function()
    if active_view and active_view.on_git_change then
      active_view:on_git_change()
      -- View may have destroyed itself (e.g. no more changes after commit)
      if active_view and active_view:is_destroyed() then active_view = nil end
    end
  end)

  _event_cleanups[#_event_cleanups + 1] = event.custom_on('VGitDirChanged', function()
    if active_view and active_view.destroy then active_view:destroy() end
    active_view = nil
  end)
end

local function show_view(ViewClass, data, name)
  if _showing then return end
  if not data then
    console.error('No ' .. name .. ' data')
    return
  end

  _showing = true
  local view
  local ok, err = pcall(function()
    if active_view and active_view.destroy then
      active_view:destroy()
      active_view = nil
    end

    event.await()

    view = ViewClass()
    local success = view:create(data)
    if success == false then
      view:destroy()
      view = nil
      return
    end
    active_view = view
  end)
  _showing = false

  if not ok then
    if view and view.destroy then pcall(view.destroy, view) end
    error(err)
  end
end

display_service.show_diff = event.async(function(data)
  if not data then
    console.error('No diff data')
    return
  end

  if data.type == 'empty' then
    console.info(data.message or 'No changes')
    return
  end

  if data.type == 'file' then
    show_view(FileDiffView, data, 'diff')
  elseif data.type == 'files' then
    if not data.entries or #data.entries == 0 then
      console.info('No changes to display')
      return
    end
    show_view(ProjectDiffView, data, 'diff')
  else
    console.error('Unknown data type: ' .. tostring(data.type))
  end
end)

display_service.show_hunk = event.async(function(data)
  show_view(HunkLensView, data, 'hunk')
end)

display_service.show_blame = event.async(function(data)
  show_view(BlameLensView, data, 'blame')
end)

display_service.show_status = event.async(function(data)
  if not data or not data.entries or #data.entries == 0 then
    console.info('No changes to display')
    return
  end

  show_view(StatusDiffView, data, 'status')
end)

display_service.show_branch = event.async(function(data)
  show_view(BranchView, data, 'branch')
end)

display_service.show_stash = event.async(function(data)
  show_view(StashView, data, 'stash')
end)

display_service.show_worktree = event.async(function(data)
  show_view(WorktreeView, data, 'worktree')
end)

display_service.show_log = event.async(function(data)
  show_view(CommitPickerView, data, 'log')
end)

display_service.show_blame_view = event.async(function(data)
  show_view(BlameView, data, 'blame view')
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
  _showing = false
  for _, cleanup in ipairs(_event_cleanups) do
    cleanup()
  end
  _event_cleanups = {}
  _events_registered = false
end

return display_service
