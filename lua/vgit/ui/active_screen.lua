local scene_setting = require('vgit.settings.scene')
local diff_preview = require('vgit.settings.diff_preview')
local DiffScreen = require('vgit.features.screens.DiffScreen')
local HistoryScreen = require('vgit.features.screens.HistoryScreen')
local ProjectDiffScreen = require('vgit.features.screens.ProjectDiffScreen')
local ProjectCommitsScreen = require(
  'vgit.features.screens.ProjectCommitsScreen'
)
local ProjectHunksScreen = require('vgit.features.screens.ProjectHunksScreen')
local GutterBlameScreen = require('vgit.features.screens.GutterBlameScreen')
local LineBlameScreen = require('vgit.features.screens.LineBlameScreen')
local DebugScreen = require('vgit.features.screens.DebugScreen')
local ProjectLogsScreen = require('vgit.features.screens.ProjectLogsScreen')
local project_diff_preview_setting = require(
  'vgit.settings.project_diff_preview'
)

local active_screen = {
  current = nil,
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
      active_screen.current = screen
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
    active_screen.current[action_name](active_screen.current, ...)
  end

  return active_screen
end

function active_screen.screens.diff_screen(opts)
  local diff_screen = DiffScreen()
  diff_screen.layout_type = scene_setting:get('diff_preference')

  return diff_screen:show(opts), diff_screen
end

function active_screen.screens.diff_hunk_screen(opts)
  local diff_hunk_screen = DiffScreen({ is_hunk = true })
  diff_hunk_screen.layout_type = scene_setting:get('diff_preference')

  return diff_hunk_screen:show(opts), diff_hunk_screen
end

function active_screen.screens.gutter_blame_screen()
  local gutter_blame_screen = GutterBlameScreen()

  return gutter_blame_screen:show(), gutter_blame_screen
end

function active_screen.screens.project_logs_screen(...)
  local project_logs_screen = ProjectLogsScreen()

  return project_logs_screen:show({ ... }), project_logs_screen
end

function active_screen.screens.project_diff_screen()
  local project_diff_screen = ProjectDiffScreen()
  project_diff_screen.layout_type = scene_setting:get('diff_preference')

  return project_diff_screen:show(), project_diff_screen
end

function active_screen.screens.project_commits_screen(...)
  local project_commits_screen = ProjectCommitsScreen()
  project_commits_screen.layout_type = scene_setting:get('diff_preference')

  return project_commits_screen:show({ ... }), project_commits_screen
end

function active_screen.screens.project_hunks_screen(opts)
  local project_hunks_screen = ProjectHunksScreen()
  project_hunks_screen.layout_type = scene_setting:get('diff_preference')

  return project_hunks_screen:show(opts), project_hunks_screen
end

function active_screen.screens.history_screen()
  local history_screen = HistoryScreen()
  history_screen.layout_type = scene_setting:get('diff_preference')

  return history_screen:show(), history_screen
end

function active_screen.screens.debug_screen(...)
  local debug_screen = DebugScreen()

  return debug_screen:show(...), debug_screen
end

function active_screen.screens.line_blame_screen()
  local line_blame_screen = LineBlameScreen()

  return line_blame_screen:show(), line_blame_screen
end

function active_screen.keys.j()
  active_screen.current:trigger_keypress('j')

  return active_screen
end

function active_screen.keys.k()
  active_screen.current:trigger_keypress('k')

  return active_screen
end

active_screen.keys['<tab>'] = function()
  active_screen.current:trigger_keypress('<tab>')

  return active_screen
end

active_screen.keys['<enter>'] = function()
  active_screen.current:trigger_keypress('<enter>')

  return active_screen
end

active_screen.keys[diff_preview:get('keymaps').toggle_view] = function()
  if active_screen.exists() then
    return active_screen.current:trigger_keypress(
      diff_preview:get('keymaps').toggle_view
    )
  end
end

active_screen.keys[diff_preview:get('keymaps').reset] = function()
  if active_screen.exists() then
    return active_screen.current:trigger_keypress(
      diff_preview:get('keymaps').reset
    )
  end
end

active_screen.keys[diff_preview:get('keymaps').buffer_stage] = function()
  if active_screen.exists() then
    return active_screen.current:trigger_keypress(
      diff_preview:get('keymaps').buffer_stage
    )
  end
end

active_screen.keys[diff_preview:get('keymaps').buffer_unstage] = function()
  if active_screen.exists() then
    return active_screen.current:trigger_keypress(
      diff_preview:get('keymaps').buffer_unstage
    )
  end
end

active_screen.keys[diff_preview:get('keymaps').buffer_hunk_stage] = function()
  if active_screen.exists() then
    return active_screen.current:trigger_keypress(
      diff_preview:get('keymaps').buffer_hunk_stage
    )
  end
end

active_screen.keys[diff_preview:get('keymaps').buffer_hunk_unstage] = function()
  if active_screen.exists() then
    return active_screen.current:trigger_keypress(
      diff_preview:get('keymaps').buffer_hunk_unstage
    )
  end
end

active_screen.keys[diff_preview:get('keymaps').reset] = function()
  if active_screen.exists() then
    return active_screen.current:trigger_keypress(
      diff_preview:get('keymaps').reset
    )
  end
end

active_screen.keys[project_diff_preview_setting:get('keymaps').buffer_stage] =
  function()
    active_screen.current:trigger_keypress(
      project_diff_preview_setting:get('keymaps').buffer_stage
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').buffer_unstage] =
  function()
    active_screen.current:trigger_keypress(
      project_diff_preview_setting:get('keymaps').buffer_unstage
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').buffer_hunk_stage] =
  function()
    active_screen.current:trigger_keypress(
      project_diff_preview_setting:get('keymaps').buffer_hunk_stage
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').buffer_hunk_unstage] =
  function()
    active_screen.current:trigger_keypress(
      project_diff_preview_setting:get('keymaps').buffer_hunk_unstage
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').stage_all] =
  function()
    active_screen.current:trigger_keypress(
      project_diff_preview_setting:get('keymaps').stage_all
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').unstage_all] =
  function()
    active_screen.current:trigger_keypress(
      project_diff_preview_setting:get('keymaps').unstage_all
    )

    return active_screen
  end

active_screen.keys[project_diff_preview_setting:get('keymaps').reset_all] =
  function()
    active_screen.current:trigger_keypress(
      project_diff_preview_setting:get('keymaps').reset_all
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
  return type(active_screen.current[action]) == 'function'
end

function active_screen.exists()
  return active_screen.current ~= nil
end

function active_screen.destroy()
  active_screen.current:destroy()
  active_screen.current = nil

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
