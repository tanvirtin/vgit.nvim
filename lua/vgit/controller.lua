local env = require('vgit.core.env')
local loop = require('vgit.core.loop')
local sign = require('vgit.core.sign')
local libgit2 = require('vgit.libgit2')
local keymap = require('vgit.core.keymap')
local console = require('vgit.core.console')
local renderer = require('vgit.core.renderer')
local highlight = require('vgit.core.highlight')
local hls_setting = require('vgit.settings.hls')
local git_setting = require('vgit.settings.git')
local Hunks = require('vgit.features.buffer.Hunks')
local scene_setting = require('vgit.settings.scene')
local signs_setting = require('vgit.settings.signs')
local libgit2_setting = require('vgit.settings.libgit2')
local screen_manager = require('vgit.ui.screen_manager')
local symbols_setting = require('vgit.settings.symbols')
local diff_preview = require('vgit.settings.diff_preview')
local Conflicts = require('vgit.features.buffer.Conflicts')
local LiveBlame = require('vgit.features.buffer.LiveBlame')
local git_buffer_store = require('vgit.git.git_buffer_store')
local LiveGutter = require('vgit.features.buffer.LiveGutter')
local live_blame_setting = require('vgit.settings.live_blame')
local live_gutter_setting = require('vgit.settings.live_gutter')
local LiveConflict = require('vgit.features.buffer.LiveConflict')
local project_diff_preview_setting = require('vgit.settings.project_diff_preview')
local project_logs_preview_setting = require('vgit.settings.project_logs_preview')
local project_stash_preview_setting = require('vgit.settings.project_stash_preview')
local project_commit_preview_setting = require('vgit.settings.project_commit_preview')

local hunks = Hunks()
local conflicts = Conflicts()
local live_blame = LiveBlame()
local live_gutter = LiveGutter()
local live_conflict = LiveConflict()

local controls = {
  hunk_up = loop.coroutine(function()
    hunks:move_up()
    conflicts:move_up()
    return screen_manager.dispatch_action('hunk_up')
  end),
  hunk_down = loop.coroutine(function()
    hunks:move_down()
    conflicts:move_down()
    return screen_manager.dispatch_action('hunk_down')
  end),
}

local buffer = {
  reset = loop.coroutine(function()
    hunks:reset_all()
  end),
  stage = loop.coroutine(function()
    hunks:stage_all()
  end),
  unstage = loop.coroutine(function()
    hunks:unstage_all()
  end),
  hunk_stage = loop.coroutine(function()
    hunks:cursor_stage()
  end),
  hunk_reset = loop.coroutine(function()
    hunks:cursor_reset()
  end),
  diff_preview = loop.coroutine(function()
    screen_manager.create('diff_screen')
  end),
  hunk_preview = loop.coroutine(function()
    screen_manager.create('diff_hunk_screen')
  end),
  history_preview = loop.coroutine(function()
    screen_manager.create('history_screen')
  end),
  blame_preview = loop.coroutine(function()
    screen_manager.create('line_blame_screen')
  end),
  conflict_accept_both = loop.coroutine(function()
    conflicts:accept_both()
  end),
  conflict_accept_current = loop.coroutine(function()
    conflicts:accept_current()
  end),
  conflict_accept_incoming = loop.coroutine(function()
    conflicts:accept_incoming()
  end),
}

local project = {
  commit_preview = loop.coroutine(function(...)
    screen_manager.create('commit_screen', ...)
  end),
  diff_preview = loop.coroutine(function()
    screen_manager.create('project_diff_screen')
  end),
  logs_preview = loop.coroutine(function(...)
    screen_manager.create('project_logs_screen', ...)
  end),
  stash_preview = loop.coroutine(function(...)
    screen_manager.create('project_stash_screen', ...)
  end),
  commits_preview = loop.coroutine(function(...)
    screen_manager.create('project_commits_screen', ...)
  end),
}

local toggle_diff_preference = loop.coroutine(function()
  screen_manager.toggle_diff_preference()
end)

local toggle_live_blame = loop.coroutine(function()
  local blames_enabled = live_blame_setting:get('enabled')

  live_blame_setting:set('enabled', not blames_enabled)
  live_blame:reset()
end)

local toggle_live_gutter = loop.coroutine(function()
  local live_gutter_enabled = live_gutter_setting:get('enabled')

  live_gutter_setting:set('enabled', not live_gutter_enabled)
  live_gutter:toggle()
end)

local toggle_tracing = loop.coroutine(function()
  env.set('DEBUG', not env.get('DEBUG'))
end)

local function help()
  vim.cmd('h vgit')
end

local function register_modules()
  highlight.register_module(function()
    sign.register_module()
  end)
  renderer.register_module()

  local _, err = libgit2.register()
  if err then console.error(err) end
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
  keymap.define(keymaps)
end

local function configure_settings(config)
  local config_settings = config and config.settings or {}

  git_setting:assign(config_settings.git)
  hls_setting:assign(config_settings.hls)
  signs_setting:assign(config_settings.signs)
  scene_setting:assign(config_settings.scene)
  libgit2_setting:assign(config_settings.libgit2)
  symbols_setting:assign(config_settings.symbols)
  diff_preview:assign(config_settings.diff_preview)
  live_blame_setting:assign(config_settings.live_blame)
  live_gutter_setting:assign(config_settings.live_gutter)
  project_diff_preview_setting:assign(config_settings.project_diff_preview)
  project_logs_preview_setting:assign(config_settings.project_logs_preview)
  project_stash_preview_setting:assign(config_settings.project_stash_preview)
  project_commit_preview_setting:assign(config_settings.project_commit_preview)
end

local controller = {}

function controller.setup(config)
  configure_settings(config)

  vim.api.nvim_create_user_command('VGit', controller.execute_command, {
    nargs = '*',
    complete = controller.autocomplete,
  })

  register_modules()
  register_events()
  register_keymaps(config)
end

function controller.commands()
  return {
    help = help,
    setup = controller.setup,
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
    buffer_conflict_accept_both = buffer.conflict_accept_both,
    buffer_conflict_accept_current = buffer.conflict_accept_current,
    buffer_conflict_accept_incoming = buffer.conflict_accept_incoming,
    project_diff_preview = project.diff_preview,
    project_logs_preview = project.logs_preview,
    project_stash_preview = project.stash_preview,
    project_commit_preview = project.commit_preview,
    project_commits_preview = project.commits_preview,
  }
end

function controller.execute_command(args)
  local commands = controller.commands()

  if not args.fargs or #args.fargs == 0 then
    vim.notify('Vgit: No command provided', vim.log.levels.ERROR)
    return
  end

  local cmd = args.fargs[1]
  local cmd_func = commands[cmd]

  if not cmd_func then
    vim.notify(string.format('Vgit: Unknown command \'%s\'', cmd), vim.log.levels.ERROR)
    return
  end

  local ok, err = pcall(cmd_func, unpack(args.fargs, 2))
  if not ok then
    vim.notify(string.format('Vgit: Error executing command \'%s\': %s', cmd, err), vim.log.levels.ERROR)
  end
end

function controller.autocomplete(arg_lead, cmd_line, _)
  local commands = controller.commands()
  local cmd_list = vim.tbl_keys(commands)

  local split_cmd = vim.split(cmd_line, '%s+')
  if #split_cmd == 2 then
    return vim.tbl_filter(function(cmd)
      return vim.startswith(cmd, arg_lead)
    end, cmd_list)
  end

  return {}
end

return controller
