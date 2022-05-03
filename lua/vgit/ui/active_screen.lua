local scene_setting = require('vgit.settings.scene')
local DiffScreen = require('vgit.features.screens.DiffScreen')
local DiffHunkScreen = require('vgit.features.screens.DiffHunkScreen')
local HistoryScreen = require('vgit.features.screens.HistoryScreen')
local StagedDiffScreen = require('vgit.features.screens.StagedDiffScreen')
local ProjectDiffScreen = require('vgit.features.screens.ProjectDiffScreen')
local ProjectCommitsScreen = require(
  'vgit.features.screens.ProjectCommitsScreen'
)
local StagedDiffHunkScreen = require(
  'vgit.features.screens.StagedDiffHunkScreen'
)
local ProjectHunksScreen = require('vgit.features.screens.ProjectHunksScreen')
local GutterBlameScreen = require('vgit.features.screens.GutterBlameScreen')
local LineBlameScreen = require('vgit.features.screens.LineBlameScreen')
local DebugScreen = require('vgit.features.screens.DebugScreen')
local project_diff_preview_setting = require(
  'vgit.settings.project_diff_preview'
)

local current_screen

local diff_screen = DiffScreen()
local diff_hunk_screen = DiffHunkScreen()
local staged_diff_screen = StagedDiffScreen()
local staged_diff_hunk_screen = StagedDiffHunkScreen()
local history_screen = HistoryScreen()
local project_diff_screen = ProjectDiffScreen()
local project_commits_screen = ProjectCommitsScreen()
local project_hunks_screen = ProjectHunksScreen()
local gutter_blame_screen = GutterBlameScreen()
local line_blame_screen = LineBlameScreen()
local debug_screen = DebugScreen()

local active_screen = {
  screens = {},
  keys = {},
}

function active_screen.activate(screen_name, ...)
  if active_screen.exists() then
    return active_screen
  end

  if active_screen.is_screen_registered(screen_name) then
    local success, screen = active_screen.screens[screen_name](...)
    if success then
      current_screen = screen
    end
  end

  return active_screen
end

function active_screen.keypress(key, ...)
  if active_screen.is_key_registered(key) then
    active_screen.keys[key](...)
  end

  return active_screen
end

function active_screen.action(action_name, ...)
  if active_screen.has_action(action_name) then
    current_screen[action_name](current_screen, ...)
  end

  return active_screen
end

function active_screen.screens.diff_screen()
  diff_screen.layout_type = scene_setting:get('diff_preference')

  return diff_screen:show(), diff_screen
end

function active_screen.screens.staged_diff_screen()
  staged_diff_screen.layout_type = scene_setting:get('diff_preference')

  return staged_diff_screen:show(), staged_diff_screen
end

function active_screen.screens.diff_hunk_screen()
  diff_hunk_screen.layout_type = scene_setting:get('diff_preference')

  return diff_hunk_screen:show(), diff_hunk_screen
end

function active_screen.screens.staged_hunk_screen()
  staged_diff_hunk_screen.layout_type = scene_setting:get('diff_preference')

  return staged_diff_hunk_screen:show(), staged_diff_hunk_screen
end

function active_screen.screens.gutter_blame_screen()
  return gutter_blame_screen:show(), gutter_blame_screen
end

function active_screen.screens.project_diff_screen()
  project_diff_screen.layout_type = scene_setting:get('diff_preference')

  return project_diff_screen:show(), project_diff_screen
end

function active_screen.screens.project_commits_screen(...)
  project_commits_screen.layout_type = scene_setting:get('diff_preference')

  return project_commits_screen:show({ ... }), project_commits_screen
end

function active_screen.screens.project_hunks_screen()
  project_hunks_screen.layout_type = scene_setting:get('diff_preference')

  return project_hunks_screen:show(), project_hunks_screen
end

function active_screen.screens.history_screen()
  history_screen.layout_type = scene_setting:get('diff_preference')

  return history_screen:show(), history_screen
end

function active_screen.screens.debug_screen(...)
  return debug_screen:show(...), debug_screen
end

function active_screen.screens.line_blame_screen()
  return line_blame_screen:show(), line_blame_screen
end

function active_screen.keys.j()
  current_screen:trigger_keypress('j')

  return active_screen
end

function active_screen.keys.k()
  current_screen:trigger_keypress('k')

  return active_screen
end

active_screen.keys['<enter>'] = function()
  current_screen:trigger_keypress('<enter>')

  return active_screen
end

active_screen.keys['<C-j>'] = function()
  current_screen:trigger_keypress('<C-j>')

  return active_screen
end

active_screen.keys['<C-k>'] = function()
  current_screen:trigger_keypress('<C-k>')

  return active_screen
end

active_screen.keys[project_diff_preview_setting:get('keymaps').buffer_stage] =
  function()
    current_screen:trigger_keypress(
      project_diff_preview_setting:get('keymaps').buffer_stage
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').buffer_unstage] =
  function()
    current_screen:trigger_keypress(
      project_diff_preview_setting:get('keymaps').buffer_unstage
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').stage_all] =
  function()
    current_screen:trigger_keypress(
      project_diff_preview_setting:get('keymaps').stage_all
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').unstage_all] =
  function()
    current_screen:trigger_keypress(
      project_diff_preview_setting:get('keymaps').unstage_all
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').reset_all] =
  function()
    current_screen:trigger_keypress(
      project_diff_preview_setting:get('keymaps').reset_all
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').clean_all] =
  function()
    current_screen:trigger_keypress(
      project_diff_preview_setting:get('keymaps').clean_all
    )

    return active_screen
  end

function active_screen.is_screen_registered(screen_name)
  return type(active_screen.screens[screen_name]) == 'function'
end

function active_screen.is_key_registered(key)
  return type(active_screen.keys[key]) == 'function'
end

function active_screen.has_action(action)
  return type(current_screen[action]) == 'function'
end

function active_screen.exists()
  return current_screen ~= nil
end

function active_screen.destroy()
  current_screen:destroy()
  current_screen = nil

  return active_screen
end

function active_screen.toggle_diff_preference()
  local diff_preference = scene_setting:get('diff_preference')

  if diff_preference == 'unified' then
    scene_setting:set('diff_preference', 'split')
  elseif diff_preference == 'split' then
    scene_setting:set('diff_preference', 'unified')
  end

  return active_screen
end

return active_screen
