local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local keymap = require('vgit.core.keymap')
local event_type = require('vgit.core.event_type')
local scene_setting = require('vgit.settings.scene')
local DiffScreen = require('vgit.features.screens.DiffScreen')
local DebugScreen = require('vgit.features.screens.DebugScreen')
local HistoryScreen = require('vgit.features.screens.HistoryScreen')
local LineBlameScreen = require('vgit.features.screens.LineBlameScreen')
local MinimizedScreen = require('vgit.features.screens.MinimizedScreen')
local ProjectDiffScreen = require('vgit.features.screens.ProjectDiffScreen')
local ProjectHunksScreen = require('vgit.features.screens.ProjectHunksScreen')
local GutterBlameScreen = require('vgit.features.screens.GutterBlameScreen')
local ProjectLogsScreen = require('vgit.features.screens.ProjectLogsScreen')
local ProjectStashScreen = require('vgit.features.screens.ProjectStashScreen')
local ProjectCommitsScreen = require('vgit.features.screens.ProjectCommitsScreen')

local minimized_screen = MinimizedScreen()

local screen_manager = {
  screens = {},
  active_screen = nil,
  is_miminmized = false,
}

function screen_manager.handle_on_quit_keypress()
  if not screen_manager.is_minimized and screen_manager.has_active_screen() then
    return screen_manager.destroy_active_screen()
  end
end

function screen_manager.handle_buf_win_enter()
  if not screen_manager.is_minimized and screen_manager.has_active_screen() then
    return screen_manager.destroy_active_screen()
  end
end

function screen_manager.handle_buf_win_leave()
  loop.await()
  if not screen_manager.is_minimized and screen_manager.has_active_screen() then
    return screen_manager.destroy_active_screen()
  end
end

function screen_manager.handle_win_enter()
  loop.await()
  if not screen_manager.is_minimized and screen_manager.has_active_screen() then
    return screen_manager.minimize_screen()
  end
  if screen_manager.is_minimized and screen_manager.has_active_screen() then
    return screen_manager.restore_screen()
  end
end

function screen_manager.register_events()
  event.on(event_type.WinEnter, screen_manager.handle_win_enter)
  event.on(event_type.BufWinEnter, screen_manager.handle_buf_win_enter)
  event.on(event_type.BufWinLeave, screen_manager.handle_buf_win_leave)
end

function screen_manager.register_keymaps()
  keymap.set('n', scene_setting:get('keymaps').quit, screen_manager.handle_on_quit_keypress)
end

function screen_manager.dispatch_action(action_name, ...)
  if
    not screen_manager.is_minimized
    and screen_manager.has_active_screen()
    and screen_manager.has_action(action_name)
  then
    screen_manager.active_screen[action_name](screen_manager.active_screen, ...)
  end

  return screen_manager
end

function screen_manager.screens.diff_screen(opts)
  local diff_screen = DiffScreen()
  diff_screen.layout_type = scene_setting:get('diff_preference')
  diff_screen.hydrate = false

  return diff_screen:show(opts), diff_screen
end

function screen_manager.screens.diff_hunk_screen(opts)
  local diff_hunk_screen = DiffScreen({ is_hunk = true })
  diff_hunk_screen.layout_type = scene_setting:get('diff_preference')
  diff_hunk_screen.hydrate = false

  return diff_hunk_screen:show(opts), diff_hunk_screen
end

function screen_manager.screens.gutter_blame_screen()
  local gutter_blame_screen = GutterBlameScreen()
  gutter_blame_screen.hydrate = false

  return gutter_blame_screen:show(), gutter_blame_screen
end

function screen_manager.screens.project_logs_screen(...)
  local project_logs_screen = ProjectLogsScreen()
  project_logs_screen.hydrate = false

  return project_logs_screen:show({ ... }), project_logs_screen
end

function screen_manager.screens.project_stash_screen(...)
  local project_stash_screen = ProjectStashScreen()
  project_stash_screen.hydrate = false

  return project_stash_screen:show({ ... }), project_stash_screen
end

function screen_manager.screens.project_diff_screen()
  local project_diff_screen = ProjectDiffScreen()
  project_diff_screen.layout_type = scene_setting:get('diff_preference')
  project_diff_screen.hydrate = false

  return project_diff_screen:show(), project_diff_screen
end

function screen_manager.screens.project_commits_screen(...)
  local project_commits_screen = ProjectCommitsScreen()
  project_commits_screen.layout_type = scene_setting:get('diff_preference')
  project_commits_screen.hydrate = false

  return project_commits_screen:show({ ... }), project_commits_screen
end

function screen_manager.screens.project_hunks_screen(opts)
  local project_hunks_screen = ProjectHunksScreen()
  project_hunks_screen.layout_type = scene_setting:get('diff_preference')
  project_hunks_screen.hydrate = false

  return project_hunks_screen:show(opts), project_hunks_screen
end

function screen_manager.screens.history_screen()
  local history_screen = HistoryScreen()
  history_screen.layout_type = scene_setting:get('diff_preference')
  history_screen.hydrate = false

  return history_screen:show(), history_screen
end

function screen_manager.screens.debug_screen(...)
  local debug_screen = DebugScreen()
  debug_screen.hydrate = false

  return debug_screen:show(...), debug_screen
end

function screen_manager.screens.line_blame_screen()
  local line_blame_screen = LineBlameScreen()
  line_blame_screen.hydrate = false

  return line_blame_screen:show(), line_blame_screen
end

function screen_manager.is_screen_registered(screen_name) return type(screen_manager.screens[screen_name]) == 'function' end

function screen_manager.has_action(action) return type(screen_manager.active_screen[action]) == 'function' end

function screen_manager.has_active_screen() return screen_manager.active_screen ~= nil end

function screen_manager.minimize_screen()
  local screen = screen_manager.active_screen
  local is_focused = screen.scene:is_focused()

  if not is_focused then
    screen:destroy()
    screen_manager.is_minimized = true
    minimized_screen:show(screen.name)
  end

  return screen_manager
end

function screen_manager.restore_screen()
  local is_focused = minimized_screen:is_focused()

  if is_focused then
    minimized_screen:destroy()
    screen_manager.active_screen.hydrate = true
    screen_manager.active_screen:show()
    screen_manager.is_minimized = false
  end

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

function screen_manager.show(screen_name, ...)
  if not screen_manager.is_screen_registered(screen_name) then
    return screen_manager
  end

  if screen_manager.has_active_screen() then
    if minimized_screen:is_mounted() then
      minimized_screen:destroy()
      screen_manager.is_minimized = false
    end
    screen_manager.destroy_active_screen()
  end

  local success, screen = screen_manager.screens[screen_name](...)
  if success then
    screen_manager.active_screen = screen
  end

  return screen_manager
end

function screen_manager.destroy_active_screen()
  screen_manager.active_screen:destroy()
  screen_manager.active_screen = nil

  return screen_manager
end

return screen_manager
