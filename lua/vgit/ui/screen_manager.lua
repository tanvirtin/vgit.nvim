local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local scene_setting = require('vgit.settings.scene')
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
local ProjectStashScreen = require('vgit.features.screens.ProjectStashScreen')

local screen_manager = {
  current = nil,
  screens = {},
  keys = {},
}

function screen_manager.activate(screen_name, ...)
  if screen_manager.exists() then
    return screen_manager
  end

  if screen_manager.is_screen_registered(screen_name) then
    local success, screen = screen_manager.screens[screen_name](...)
    if success then
      screen_manager.current = screen
    end
  end

  return screen_manager
end

function screen_manager.dispatch_action(action_name, ...)
  if screen_manager.has_action(action_name) then
    screen_manager.current[action_name](screen_manager.current, ...)
  end

  return screen_manager
end

function screen_manager.screens.diff_screen(opts)
  local diff_screen = DiffScreen()
  diff_screen.layout_type = scene_setting:get('diff_preference')

  return diff_screen:show(opts), diff_screen
end

function screen_manager.screens.diff_hunk_screen(opts)
  local diff_hunk_screen = DiffScreen({ is_hunk = true })
  diff_hunk_screen.layout_type = scene_setting:get('diff_preference')

  return diff_hunk_screen:show(opts), diff_hunk_screen
end

function screen_manager.screens.gutter_blame_screen()
  local gutter_blame_screen = GutterBlameScreen()

  return gutter_blame_screen:show(), gutter_blame_screen
end

function screen_manager.screens.project_logs_screen(...)
  local project_logs_screen = ProjectLogsScreen()

  return project_logs_screen:show({ ... }), project_logs_screen
end

function screen_manager.screens.project_stash_screen(...)
  local project_stash_screen = ProjectStashScreen()

  return project_stash_screen:show({ ... }), project_stash_screen
end

function screen_manager.screens.project_diff_screen()
  local project_diff_screen = ProjectDiffScreen()
  project_diff_screen.layout_type = scene_setting:get('diff_preference')

  return project_diff_screen:show(), project_diff_screen
end

function screen_manager.screens.project_commits_screen(...)
  local project_commits_screen = ProjectCommitsScreen()
  project_commits_screen.layout_type = scene_setting:get('diff_preference')

  return project_commits_screen:show({ ... }), project_commits_screen
end

function screen_manager.screens.project_hunks_screen(opts)
  local project_hunks_screen = ProjectHunksScreen()
  project_hunks_screen.layout_type = scene_setting:get('diff_preference')

  return project_hunks_screen:show(opts), project_hunks_screen
end

function screen_manager.screens.history_screen()
  local history_screen = HistoryScreen()
  history_screen.layout_type = scene_setting:get('diff_preference')

  return history_screen:show(), history_screen
end

function screen_manager.screens.debug_screen(...)
  local debug_screen = DebugScreen()

  return debug_screen:show(...), debug_screen
end

function screen_manager.screens.line_blame_screen()
  local line_blame_screen = LineBlameScreen()

  return line_blame_screen:show(), line_blame_screen
end

function screen_manager.is_screen_registered(screen_name)
  return type(screen_manager.screens[screen_name]) == 'function'
end

function screen_manager.has_action(action)
  return type(screen_manager.current[action]) == 'function'
end

function screen_manager.exists()
  return screen_manager.current ~= nil
end

function screen_manager.destroy()
  screen_manager.current:destroy()
  screen_manager.current = nil

  return screen_manager
end

function screen_manager.toggle_diff_preference()
  local diff_preference = scene_setting:get('diff_preference')

  if diff_preference == 'unified' then
    scene_setting:set('diff_preference', 'split')
  elseif diff_preference == 'split' then
    scene_setting:set('diff_preference', 'unified')
  end

  return screen_manager
end

function screen_manager.register_events()
  event.on('BufWinEnter', function()
    if screen_manager.exists() then
      return screen_manager.destroy()
    end
  end).on('BufWinLeave', function()
    loop.await_fast_event()
    if screen_manager.exists() then
      return screen_manager.destroy()
    end
  end)
end

return screen_manager
