local Git = require('vgit.cli.Git')
local scene_setting = require('vgit.settings.scene')
local DiffScene = require('vgit.features.scenes.DiffScene')
local HistoryScene = require('vgit.features.scenes.HistoryScene')
local StagedDiffScene = require('vgit.features.scenes.StagedDiffScene')
local ProjectDiffScene = require('vgit.features.scenes.ProjectDiffScene')
local ProjectHunksScene = require('vgit.features.scenes.ProjectHunksScene')
local GutterBlameScene = require('vgit.features.scenes.GutterBlameScene')
local LineBlameScene = require('vgit.features.scenes.LineBlameScene')

local current_scene
local diff_scene
local staged_diff_scene
local history_scene
local project_diff_scene
local project_hunks_scene
local gutter_blame_scene
local line_blame_scene

local active_scene = {}

-- Factory and dependency injection
active_scene.inject = function(buffer_hunks, navigation, git_store)
  diff_scene = DiffScene:new(buffer_hunks, navigation, git_store, Git:new())
  staged_diff_scene = StagedDiffScene:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  history_scene = HistoryScene:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  project_diff_scene = ProjectDiffScene:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  project_hunks_scene = ProjectHunksScene:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  gutter_blame_scene = GutterBlameScene:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
  line_blame_scene = LineBlameScene:new(
    buffer_hunks,
    navigation,
    git_store,
    Git:new()
  )
end

active_scene.diff_scene = function()
  if active_scene.exists() then
    return
  end
  diff_scene.layout_type = scene_setting:get('diff_preference')
  local success = diff_scene:show('Diff')
  if success then
    current_scene = diff_scene
  end
end

active_scene.staged_diff_scene = function()
  if active_scene.exists() then
    return
  end
  staged_diff_scene.layout_type = scene_setting:get('diff_preference')
  local success = staged_diff_scene:show('Staged Diff')
  if success then
    current_scene = staged_diff_scene
  end
end

active_scene.hunk_scene = function()
  if active_scene.exists() then
    return
  end
  diff_scene.layout_type = scene_setting:get('diff_preference')
  local success = diff_scene:show('Hunk', {
    config = {
      window_props = {
        relative = 'cursor',
        height = 20,
      },
    },
  })
  if success then
    current_scene = diff_scene
  end
end

active_scene.staged_hunk_scene = function()
  if active_scene.exists() then
    return
  end
  staged_diff_scene.layout_type = scene_setting:get('diff_preference')
  local success = staged_diff_scene:show('Staged Hunk', {
    config = {
      window_props = {
        relative = 'cursor',
        height = 20,
      },
    },
  })
  if success then
    current_scene = staged_diff_scene
  end
end

active_scene.gutter_blame_scene = function()
  if active_scene.exists() then
    return
  end
  local success = gutter_blame_scene:show('Gutter Blame')
  if success then
    current_scene = gutter_blame_scene
  end
end

active_scene.project_diff_scene = function()
  if active_scene.exists() then
    return
  end
  project_diff_scene.layout_type = scene_setting:get('diff_preference')
  local success = project_diff_scene:show('Project Diff')
  if success then
    current_scene = project_diff_scene
  end
end

active_scene.project_hunks_scene = function()
  if active_scene.exists() then
    return
  end
  project_hunks_scene.layout_type = scene_setting:get('diff_preference')
  local success = project_hunks_scene:show('Project Hunks')
  if success then
    current_scene = project_hunks_scene
  end
end

active_scene.history_scene = function()
  if active_scene.exists() then
    return
  end
  history_scene.layout_type = scene_setting:get('diff_preference')
  local success = history_scene:show('History')
  if success then
    current_scene = history_scene
  end
end

active_scene.line_blame_scene = function()
  if active_scene.exists() then
    return
  end
  local success = line_blame_scene:show('History')
  if success then
    current_scene = line_blame_scene
  end
end

active_scene.has_action = function(action)
  return type(current_scene[action]) == 'function'
end

active_scene.on_enter = function()
  if active_scene.has_action('table_change') then
    current_scene:table_change()
  end
  if active_scene.has_action('open_file') then
    current_scene:open_file()
  end
end

active_scene.on_j = function()
  if active_scene.has_action('table_move') then
    current_scene:table_move('down')
  end
end

active_scene.on_k = function()
  if active_scene.has_action('table_move') then
    current_scene:table_move('up')
  end
end

active_scene.git_stage = function()
  if active_scene.has_action('git_stage') then
    current_scene:git_stage()
  end
end

active_scene.git_unstage = function()
  if active_scene.has_action('git_unstage') then
    current_scene:git_unstage()
  end
end

active_scene.git_reset = function()
  if active_scene.has_action('git_reset') then
    current_scene:git_reset()
  end
end

active_scene.refresh = function()
  if active_scene.has_action('refresh') then
    current_scene:refresh()
  end
end

active_scene.navigate = function(direction)
  if active_scene.has_action('navigate') then
    current_scene:navigate(direction)
  end
end

active_scene.keep_focused = function()
  current_scene:keep_focused()
end

active_scene.exists = function()
  return current_scene ~= nil
end

active_scene.destroy = function()
  current_scene:destroy()
  current_scene = nil
end

active_scene.toggle_diff_preference = function()
  local diff_preference = scene_setting:get('diff_preference')
  if diff_preference == 'unified' then
    scene_setting:set('diff_preference', 'split')
  elseif diff_preference == 'split' then
    scene_setting:set('diff_preference', 'unified')
  end
end

return active_scene
