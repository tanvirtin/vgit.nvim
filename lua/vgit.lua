local env = require('vgit.core.env')
local loop = require('vgit.core.loop')
local sign = require('vgit.core.sign')
local Command = require('vgit.Command')
local keymap = require('vgit.core.keymap')
local console = require('vgit.core.console')
local git_repo = require('vgit.git.git2.repo')
local renderer = require('vgit.core.renderer')
local highlight = require('vgit.core.highlight')
local hls_setting = require('vgit.settings.hls')
local git_setting = require('vgit.settings.git')
local Hunks = require('vgit.features.buffer.Hunks')
local scene_setting = require('vgit.settings.scene')
local signs_setting = require('vgit.settings.signs')
local screen_manager = require('vgit.ui.screen_manager')
local symbols_setting = require('vgit.settings.symbols')
local diff_preview = require('vgit.settings.diff_preview')
local LiveBlame = require('vgit.features.buffer.LiveBlame')
local git_buffer_store = require('vgit.git.git_buffer_store')
local LiveGutter = require('vgit.features.buffer.LiveGutter')
local live_blame_setting = require('vgit.settings.live_blame')
local live_gutter_setting = require('vgit.settings.live_gutter')
local LiveConflict = require('vgit.features.buffer.LiveConflict')
local project_diff_preview_setting = require('vgit.settings.project_diff_preview')
local ProjectHunksQuickfix = require('vgit.features.quickfix.ProjectHunksQuickfix')
local project_commit_preview_setting = require('vgit.settings.project_commit_preview')

local hunks = Hunks()
local command = Command()
local live_blame = LiveBlame()
local live_gutter = LiveGutter()
local live_conflict = LiveConflict()
local project_hunks_quickfix = ProjectHunksQuickfix()

local settings = {
  screen = scene_setting,
  hls = hls_setting,
  symbols = symbols_setting,
  signs = signs_setting,
  git = git_setting,
  live_blame = live_blame_setting,
}

local controls = {
  hunk_up = loop.coroutine(function()
    hunks:move_up()

    return screen_manager.dispatch_action('hunk_up')
  end),

  hunk_down = loop.coroutine(function()
    hunks:move_down()

    return screen_manager.dispatch_action('hunk_down')
  end),
}

local buffer = {
  reset = loop.coroutine(function() hunks:reset_all() end),
  stage = loop.coroutine(function() hunks:stage_all() end),
  unstage = loop.coroutine(function() hunks:unstage_all() end),
  hunk_stage = loop.coroutine(function() hunks:cursor_stage() end),
  hunk_reset = loop.coroutine(function() hunks:cursor_reset() end),
  diff_preview = loop.coroutine(function() screen_manager.show('diff_screen') end),
  hunk_preview = loop.coroutine(function() screen_manager.show('diff_hunk_screen') end),
  history_preview = loop.coroutine(function() screen_manager.show('history_screen') end),
  blame_preview = loop.coroutine(function() screen_manager.show('line_blame_screen') end),
  gutter_blame_preview = loop.coroutine(function() screen_manager.show('gutter_blame_screen') end),
  diff_staged_preview = loop.coroutine(function() screen_manager.show('diff_screen', { is_staged = true }) end),
  hunk_staged_preview = loop.coroutine(function() screen_manager.show('diff_hunk_screen', { is_staged = true }) end),
  conflict_accept_current_change = loop.coroutine(function() 
    local buffer = git_buffer_store:current()
    if not buffer then return end
    live_conflict:conflict_accept_current_change(buffer)
  end),
  conflict_accept_incoming_change = loop.coroutine(function()
    local buffer = git_buffer_store:current()
    if not buffer then return end
    live_conflict:conflict_accept_incoming_change(buffer)
  end),
  conflict_accept_both_changes = loop.coroutine(function()
    local buffer = git_buffer_store:current()
    if not buffer then return end
    live_conflict:conflict_accept_both_changes(buffer)
  end),
}

local project = {
  hunks_qf = loop.coroutine(function() project_hunks_quickfix:show() end),
  debug_preview = loop.coroutine(function(...) screen_manager.show('debug_screen', ...) end),
  commit_preview = loop.coroutine(function(...) screen_manager.show('commit_screen', ...) end),
  hunks_preview = loop.coroutine(function() screen_manager.show('project_hunks_screen') end),
  diff_preview = loop.coroutine(function() screen_manager.show('project_diff_screen') end),
  logs_preview = loop.coroutine(function(...) screen_manager.show('project_logs_screen', ...) end),
  stash_preview = loop.coroutine(function(...) screen_manager.show('project_stash_screen', ...) end),
  commits_preview = loop.coroutine(function(...) screen_manager.show('project_commits_screen', ...) end),
  hunks_staged_preview = loop.coroutine(function() screen_manager.show('project_hunks_screen', { is_staged = true }) end),
  reset_all = loop.coroutine(function()
    local decision = console.input('Are you sure you want to discard all tracked changes? (y/N) '):lower()
    if decision ~= 'yes' and decision ~= 'y' then return end

    local reponame = git_repo.discover()
    git_repo.reset(reponame)
  end),
}

local toggle_diff_preference = loop.coroutine(function() screen_manager.toggle_diff_preference() end)

local toggle_live_blame = loop.coroutine(function()
  local blames_enabled = live_blame_setting:get('enabled')

  live_blame_setting:set('enabled', not blames_enabled)
  live_blame:reset()
end)

local toggle_live_gutter = loop.coroutine(function()
  local live_gutter_enabled = live_gutter_setting:get('enabled')

  live_gutter_setting:set('enabled', not live_gutter_enabled)
  live_gutter:reset()
end)

local toggle_tracing = loop.coroutine(function() env.set('DEBUG', not env.get('DEBUG')) end)

local function command_list(...) return command:list(...) end

local function execute_command(...) command:execute(...) end

local function help() vim.cmd('h vgit') end

local function setup_commands()
  vim.cmd(
    string.format(
      'command! -nargs=* -range %s %s',
      '-complete=customlist,v:lua.package.loaded.vgit.command_list',
      'VGit lua _G.package.loaded.vgit.execute_command(<f-args>)'
    )
  )
end

local function register_modules()
  highlight.register_module(function() sign.register_module() end)
  renderer.register_module()
end

local function register_events()
  live_blame:register_events()
  live_gutter:register_events()
  highlight.register_events()
  git_buffer_store.register_events()
  live_conflict:register_events()
end

local function register_keymaps(config)
  local keymaps = config and config.keymaps or {}

  screen_manager.register_keymaps()
  keymap.define(keymaps)
end

local function configure_settings(config)
  local config_settings = config and config.settings or {}

  git_setting:assign(config_settings.git)
  hls_setting:assign(config_settings.hls)
  signs_setting:assign(config_settings.signs)
  scene_setting:assign(config_settings.scene)
  symbols_setting:assign(config_settings.symbols)
  diff_preview:assign(config_settings.diff_preview)
  live_blame_setting:assign(config_settings.live_blame)
  live_gutter_setting:assign(config_settings.live_gutter)
  project_diff_preview_setting:assign(config_settings.project_diff_preview)
  project_commit_preview_setting:assign(config_settings.project_commit_preview)
end

local setup = function(config)
  configure_settings(config)

  setup_commands()
  register_modules()
  register_events()
  register_keymaps(config)
end

return {
  h = help,
  help = help,
  setup = setup,
  command_list = command_list,
  execute_command = execute_command,

  settings = settings,

  toggle_tracing = toggle_tracing,
  toggle_live_blame = toggle_live_blame,
  toggle_live_gutter = toggle_live_gutter,
  toggle_diff_preference = toggle_diff_preference,

  hunk_up = controls.hunk_up,
  hunk_down = controls.hunk_down,

  buffer_reset = buffer.reset,
  buffer_stage = buffer.stage,
  buffer_unstage = buffer.unstage,
  buffer_hunk_reset = buffer.hunk_reset,
  buffer_hunk_stage = buffer.hunk_stage,
  buffer_hunk_preview = buffer.hunk_preview,
  buffer_diff_preview = buffer.diff_preview,
  buffer_blame_preview = buffer.blame_preview,
  buffer_history_preview = buffer.history_preview,
  buffer_hunk_staged_preview = buffer.hunk_staged_preview,
  buffer_diff_staged_preview = buffer.diff_staged_preview,
  buffer_gutter_blame_preview = buffer.gutter_blame_preview,

  buffer_conflict_accept_current_change = buffer.conflict_accept_current_change,
  buffer_conflict_accept_incoming_change = buffer.conflict_accept_incoming_change,
  buffer_conflict_accept_both_changes = buffer.conflict_accept_both_changes,

  project_hunks_qf = project.hunks_qf,
  project_diff_preview = project.diff_preview,
  project_logs_preview = project.logs_preview,
  project_stash_preview = project.stash_preview,
  project_hunks_preview = project.hunks_preview,
  project_debug_preview = project.debug_preview,
  project_commit_preview = project.commit_preview,
  project_commits_preview = project.commits_preview,
  project_hunks_staged_preview = project.hunks_staged_preview,
}
