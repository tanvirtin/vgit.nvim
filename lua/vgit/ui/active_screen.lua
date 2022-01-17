local Git = require('vgit.cli.Git')
local scene_setting = require('vgit.settings.scene')
local DiffScreen = require('vgit.features.screens.DiffScreen')
local DiffHunkScreen = require('vgit.features.screens.DiffHunkScreen')
local HistoryScreen = require('vgit.features.screens.HistoryScreen')
local StagedDiffScreen = require('vgit.features.screens.StagedDiffScreen')
local StagedDiffHunkScreen = require(
  'vgit.features.screens.StagedDiffHunkScreen'
)
local ProjectDiffScreen = require('vgit.features.screens.ProjectDiffScreen')
local ProjectHunksScreen = require('vgit.features.screens.ProjectHunksScreen')
local GutterBlameScreen = require('vgit.features.screens.GutterBlameScreen')
local LineBlameScreen = require('vgit.features.screens.LineBlameScreen')

local current_screen
local diff_screen
local diff_hunk_screen
local staged_diff_screen
local staged_diff_hunk_screen
local history_screen
local project_diff_screen
local project_hunks_screen
local gutter_blame_screen
local line_blame_screen

local active_screen = {
  screens = {},
  actions = {},
  keys = {},
}

-- Factory and dependency injection
active_screen.inject = function(buffer_hunks, navigation, git_store)
  diff_screen = DiffScreen:new(buffer_hunks, navigation, git_store, Git:new())
  diff_hunk_screen = DiffHunkScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  staged_diff_screen = StagedDiffScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  staged_diff_hunk_screen = StagedDiffHunkScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  history_screen = HistoryScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  project_diff_screen = ProjectDiffScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  project_hunks_screen = ProjectHunksScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  gutter_blame_screen = GutterBlameScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  line_blame_screen = LineBlameScreen:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
end

active_screen.activate = function(screen_name)
  if active_screen.exists() then
    return
  end
  if active_screen.is_screen_registered(screen_name) then
    local success, screen = active_screen.screens[screen_name]()
    if success then
      current_screen = screen
    end
  end
end

active_screen.keypress = function(key, ...)
  if active_screen.is_key_registered(key) then
    active_screen.keys[key](...)
  end
end

active_screen.action = function(action_name, ...)
  if active_screen.has_action(action_name) then
    active_screen.actions[action_name](...)
  end
end

active_screen.screens.diff_screen = function()
  diff_screen.layout_type = scene_setting:get('diff_preference')
  return diff_screen:show('Diff'), diff_screen
end

active_screen.screens.staged_diff_screen = function()
  staged_diff_screen.layout_type = scene_setting:get('diff_preference')
  return staged_diff_screen:show('Staged Diff'), staged_diff_screen
end

active_screen.screens.diff_hunk_screen = function()
  diff_hunk_screen.layout_type = scene_setting:get('diff_preference')
  return diff_hunk_screen:show('Hunk'), diff_hunk_screen
end

active_screen.screens.staged_hunk_screen = function()
  staged_diff_hunk_screen.layout_type = scene_setting:get('diff_preference')
  return staged_diff_hunk_screen:show('Staged Hunk'), staged_diff_hunk_screen
end

active_screen.screens.gutter_blame_screen = function()
  return gutter_blame_screen:show('Gutter Blame'), gutter_blame_screen
end

active_screen.screens.project_diff_screen = function()
  project_diff_screen.layout_type = scene_setting:get('diff_preference')
  return project_diff_screen:show('Project Diff'), project_diff_screen
end

active_screen.screens.project_hunks_screen = function()
  project_hunks_screen.layout_type = scene_setting:get('diff_preference')
  return project_hunks_screen:show('Project Hunks'), project_hunks_screen
end

active_screen.screens.history_screen = function()
  history_screen.layout_type = scene_setting:get('diff_preference')
  return history_screen:show('History'), history_screen
end

active_screen.screens.line_blame_screen = function()
  return line_blame_screen:show(), line_blame_screen
end

active_screen.keys['<enter>'] = function()
  current_screen:trigger_keypress('<enter>')
end

active_screen.keys.j = function()
  current_screen:trigger_keypress('j')
end

active_screen.keys.k = function()
  current_screen:trigger_keypress('k')
end

active_screen.actions.navigate = function(direction)
  current_screen:navigate(direction)
end

active_screen.actions.git_stage = function()
  current_screen:git_stage()
end

active_screen.actions.git_unstage = function()
  current_screen:git_unstage()
end

active_screen.actions.git_reset = function()
  current_screen:git_reset()
end

active_screen.actions.refresh = function()
  current_screen:refresh()
end

active_screen.keep_focused = function()
  current_screen:keep_focused()
end

active_screen.is_screen_registered = function(screen_name)
  return type(active_screen.screens[screen_name]) == 'function'
end

active_screen.is_key_registered = function(key)
  return type(active_screen.keys[key]) == 'function'
end

active_screen.has_action = function(action)
  return type(current_screen[action]) == 'function'
end

active_screen.exists = function()
  return current_screen ~= nil
end

active_screen.destroy = function()
  current_screen:destroy()
  current_screen = nil
end

active_screen.toggle_diff_preference = function()
  local diff_preference = scene_setting:get('diff_preference')
  if diff_preference == 'unified' then
    scene_setting:set('diff_preference', 'split')
  elseif diff_preference == 'split' then
    scene_setting:set('diff_preference', 'unified')
  end
end

return active_screen
