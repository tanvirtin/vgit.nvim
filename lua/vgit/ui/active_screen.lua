local Git = require('vgit.cli.Git')
local scene_setting = require('vgit.settings.scene')
local DiffScreen = require('vgit.features.screens.DiffScreen')
local HistoryScreen = require('vgit.features.screens.HistoryScreen')
local StagedDiffScreen = require('vgit.features.screens.StagedDiffScreen')
local ProjectDiffScreen = require('vgit.features.screens.ProjectDiffScreen')
local ProjectHunksScreen = require('vgit.features.screens.ProjectHunksScreen')
local GutterBlameScreen = require('vgit.features.screens.GutterBlameScreen')
local LineBlameScreen = require('vgit.features.screens.LineBlameScreen')

local current_screen
local diff_screen
local staged_diff_screen
local history_screen
local project_diff_screen
local project_hunks_screen
local gutter_blame_screen
local line_blame_screen

local active_screen = {}

-- Factory and dependency injection
active_screen.inject = function(buffer_hunks, navigation, git_store)
  diff_screen = DiffScreen:new(buffer_hunks, navigation, git_store, Git:new())
  staged_diff_screen = StagedDiffScreen:new(
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

active_screen.diff_screen = function()
  if active_screen.exists() then
    return
  end
  diff_screen.layout_type = scene_setting:get('diff_preference')
  local success = diff_screen:show('Diff')
  if success then
    current_screen = diff_screen
  end
end

active_screen.staged_diff_screen = function()
  if active_screen.exists() then
    return
  end
  staged_diff_screen.layout_type = scene_setting:get('diff_preference')
  local success = staged_diff_screen:show('Staged Diff')
  if success then
    current_screen = staged_diff_screen
  end
end

active_screen.hunk_screen = function()
  if active_screen.exists() then
    return
  end
  diff_screen.layout_type = scene_setting:get('diff_preference')
  local success = diff_screen:show('Hunk', {
    config = {
      window_props = {
        relative = 'cursor',
        height = 20,
      },
    },
  })
  if success then
    current_screen = diff_screen
  end
end

active_screen.staged_hunk_screen = function()
  if active_screen.exists() then
    return
  end
  staged_diff_screen.layout_type = scene_setting:get('diff_preference')
  local success = staged_diff_screen:show('Staged Hunk', {
    config = {
      window_props = {
        relative = 'cursor',
        height = 20,
      },
    },
  })
  if success then
    current_screen = staged_diff_screen
  end
end

active_screen.gutter_blame_screen = function()
  if active_screen.exists() then
    return
  end
  local success = gutter_blame_screen:show('Gutter Blame')
  if success then
    current_screen = gutter_blame_screen
  end
end

active_screen.project_diff_screen = function()
  if active_screen.exists() then
    return
  end
  project_diff_screen.layout_type = scene_setting:get('diff_preference')
  local success = project_diff_screen:show('Project Diff')
  if success then
    current_screen = project_diff_screen
  end
end

active_screen.project_hunks_screen = function()
  if active_screen.exists() then
    return
  end
  project_hunks_screen.layout_type = scene_setting:get('diff_preference')
  local success = project_hunks_screen:show('Project Hunks')
  if success then
    current_screen = project_hunks_screen
  end
end

active_screen.history_screen = function()
  if active_screen.exists() then
    return
  end
  history_screen.layout_type = scene_setting:get('diff_preference')
  local success = history_screen:show('History')
  if success then
    current_screen = history_screen
  end
end

active_screen.line_blame_screen = function()
  if active_screen.exists() then
    return
  end
  local success = line_blame_screen:show()
  if success then
    current_screen = line_blame_screen
  end
end

active_screen.has_action = function(action)
  return type(current_screen[action]) == 'function'
end

active_screen.on_enter = function()
  if active_screen.has_action('table_change') then
    current_screen:table_change()
  end
  if active_screen.has_action('open_file') then
    current_screen:open_file()
  end
end

active_screen.on_j = function()
  if active_screen.has_action('table_move') then
    current_screen:table_move('down')
  end
end

active_screen.on_k = function()
  if active_screen.has_action('table_move') then
    current_screen:table_move('up')
  end
end

active_screen.git_stage = function()
  if active_screen.has_action('git_stage') then
    current_screen:git_stage()
  end
end

active_screen.git_unstage = function()
  if active_screen.has_action('git_unstage') then
    current_screen:git_unstage()
  end
end

active_screen.git_reset = function()
  if active_screen.has_action('git_reset') then
    current_screen:git_reset()
  end
end

active_screen.refresh = function()
  if active_screen.has_action('refresh') then
    current_screen:refresh()
  end
end

active_screen.navigate = function(direction)
  if active_screen.has_action('navigate') then
    current_screen:navigate(direction)
  end
end

active_screen.keep_focused = function()
  current_screen:keep_focused()
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
