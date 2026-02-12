local lazy = require('vgit.core.lazy')
local env = lazy('vgit.core.env')
local sign = lazy('vgit.core.sign')
local libgit2 = lazy('vgit.libgit2')
local event = lazy('vgit.core.event')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local renderer = lazy('vgit.core.renderer')
local highlight = lazy('vgit.core.highlight')
local hls_setting = lazy('vgit.settings.hls')
local git_setting = lazy('vgit.settings.git')
local Hunks = lazy('vgit.features.buffer.Hunks')
local hunks_setting = lazy('vgit.settings.hunks')
local scene_setting = lazy('vgit.settings.scene')
local signs_setting = lazy('vgit.settings.signs')
local symbols_setting = lazy('vgit.settings.symbols')
local libgit2_setting = lazy('vgit.settings.libgit2')
local display_service = lazy('vgit.ui.display_service')
local Conflicts = lazy('vgit.features.buffer.Conflicts')
local LiveBlame = lazy('vgit.features.buffer.LiveBlame')
local status_diff_view_setting = lazy('vgit.settings.status_diff_view')
local git_buffer_store = lazy('vgit.git.git_buffer_store')
local LiveGutter = lazy('vgit.features.buffer.LiveGutter')
local live_blame_setting = lazy('vgit.settings.live_blame')
local live_gutter_setting = lazy('vgit.settings.live_gutter')
local file_diff_view_setting = lazy('vgit.settings.file_diff_view')
local project_diff_view_setting = lazy('vgit.settings.project_diff_view')
local LiveConflict = lazy('vgit.features.buffer.LiveConflict')

local hunks = Hunks()
local conflicts = Conflicts()
local live_blame = LiveBlame()
local live_gutter = LiveGutter()
local live_conflict = LiveConflict()

local controls = {
  hunk_up = event.async(function()
    hunks:hunk_up()
    conflicts:hunk_up()
  end),
  hunk_down = event.async(function()
    hunks:hunk_down()
    conflicts:hunk_down()
  end),
}

local buffer = {
  reset = event.async(function()
    hunks:reset_all()
  end),
  stage = event.async(function()
    hunks:stage_all()
  end),
  unstage = event.async(function()
    hunks:unstage_all()
  end),
  hunk_stage = event.async(function()
    hunks:cursor_stage()
  end),
  hunk_reset = event.async(function()
    hunks:cursor_reset()
  end),
  conflict_accept_both = event.async(function()
    conflicts:accept_both()
  end),
  conflict_accept_current = event.async(function()
    conflicts:accept_current()
  end),
  conflict_accept_incoming = event.async(function()
    conflicts:accept_incoming()
  end),
}

local toggle_diff_preference = event.async(function()
  display_service.toggle_diff_preference()
end)

local toggle_live_blame = event.async(function()
  local blames_enabled = live_blame_setting:get('enabled')
  if blames_enabled then live_blame:cleanup() end

  live_blame_setting:set('enabled', not blames_enabled)
  live_blame:reset()
end)

local toggle_live_gutter = event.async(function()
  local live_gutter_enabled = live_gutter_setting:get('enabled')
  if live_gutter_enabled then live_gutter:cleanup() end

  live_gutter_setting:set('enabled', not live_gutter_enabled)
  live_gutter:toggle()
end)

local toggle_tracing = event.async(function()
  env.set('DEBUG', not env.get('DEBUG'))
end)

local function help()
  if display_service.help() then return end
  vim.cmd('h vgit')
end

local function register_modules()
  highlight.register_module(function()
    sign.register_module()
  end)
  renderer.register_module()

  local _, err = libgit2.register_module()
  if err then console.error(err) end

  event.register_module()
end

local function register_events()
  display_service.register_events()
  live_blame:register_events()
  live_gutter:register_events()
  highlight.register_events()
  git_buffer_store.register_events()
  live_conflict:register_events()

  event.on({ 'VimLeavePre' }, function()
    live_blame:cleanup()
    live_gutter:cleanup()
    live_conflict:cleanup()
  end)
end

local function register_keymaps(config)
  local keymaps = config and config.keymaps or {}
  keymap.define(keymaps)
end

local function configure_settings(config)
  local config_settings = config and config.settings or {}

  hunks_setting:assign(config_settings.hunks)

  git_setting:assign(config_settings.git)
  hls_setting:assign(config_settings.hls)
  signs_setting:assign(config_settings.signs)
  scene_setting:assign(config_settings.scene)
  libgit2_setting:assign(config_settings.libgit2)
  symbols_setting:assign(config_settings.symbols)
  live_blame_setting:assign(config_settings.live_blame)
  live_gutter_setting:assign(config_settings.live_gutter)
  file_diff_view_setting:assign(config_settings.file_diff_view)
  status_diff_view_setting:assign(config_settings.status_diff_view)
  project_diff_view_setting:assign(config_settings.project_diff_view)
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
    buffer_conflict_accept_both = buffer.conflict_accept_both,
    buffer_conflict_accept_current = buffer.conflict_accept_current,
    buffer_conflict_accept_incoming = buffer.conflict_accept_incoming,
  }
end

controller.execute_command = event.async(function(args)
  if not args.fargs or #args.fargs == 0 then
    vim.notify('Vgit: No command provided', vim.log.levels.ERROR)
    return
  end

  local cmd = args.fargs[1]

  local porcelain_commands = {
    diff = true,
    blame = true,
    hunk = true,
    log = true,
    show = true,
    status = true,
  }

  if porcelain_commands[cmd] then
    local router = require('vgit.cli.router')
    router.execute(args.fargs)
    return
  end

  local commands = controller.commands()
  local cmd_func = commands[cmd]

  if cmd_func then
    cmd_func(unpack(args.fargs, 2))
    return
  end

  vim.notify(string.format('VGit: Unknown command "%s"', cmd), vim.log.levels.ERROR)
end)

function controller.autocomplete(arg_lead, cmd_line, _)
  local split_cmd = vim.split(cmd_line, '%s+')

  if #split_cmd == 2 then
    local commands = controller.commands()
    local all_commands = vim.tbl_keys(commands)

    vim.list_extend(all_commands, { 'diff', 'blame', 'hunk', 'status', 'show' })

    return vim.tbl_filter(function(cmd)
      return vim.startswith(cmd, arg_lead)
    end, all_commands)
  end

  local cmd = split_cmd[2]
  if cmd == 'diff' or cmd == 'blame' or cmd == 'hunk' then
    local git_porcelain = require('vgit.cli.git_porcelain')
    local porcelain = git_porcelain()
    local command_def = porcelain:get_command(cmd)
    if command_def and command_def.options then
      local options = {}
      for opt_name, _ in pairs(command_def.options) do
        table.insert(options, '--' .. opt_name)
      end
      return vim.tbl_filter(function(opt)
        return vim.startswith(opt, arg_lead)
      end, options)
    end
  end

  return {}
end

return controller.commands()
