local env = require('vgit.core.env')
local hls_setting = require('vgit.settings.hls')
local live_blame_setting = require('vgit.settings.live_blame')
local live_gutter_setting = require('vgit.settings.live_gutter')
local scene_setting = require('vgit.settings.scene')
local signs_setting = require('vgit.settings.signs')
local loop = require('vgit.core.loop')
local symbols_setting = require('vgit.settings.symbols')
local keymap = require('vgit.core.keymap')
local highlight = require('vgit.core.highlight')
local sign = require('vgit.core.sign')
local Command = require('vgit.Command')
local Navigation = require('vgit.Navigation')
local Marker = require('vgit.Marker')
local GitStore = require('vgit.GitStore')
local autocmd = require('vgit.core.autocmd')
local LiveGutter = require('vgit.features.LiveGutter')
local LiveBlame = require('vgit.features.LiveBlame')
local ProjectHunksList = require('vgit.features.ProjectHunksList')
local BufferHunks = require('vgit.features.BufferHunks')
local Git = require('vgit.cli.Git')
local Versioning = require('vgit.core.Versioning')
local active_scene = require('vgit.ui.active_scene')

local versioning = Versioning:new()
local git = Git:new()
local command = Command:new()
local navigation = Navigation:new()
local marker = Marker:new()
local git_store = GitStore:new()
local live_gutter = LiveGutter:new(git_store)
local live_blame = LiveBlame:new(git_store)
local buffer_hunks = BufferHunks:new(git_store, navigation, marker)
local project_hunks_list = ProjectHunksList:new()

active_scene.inject(buffer_hunks, navigation, git_store)

local function prevent_default() end

local on_enter = loop.async(function()
  if active_scene.exists() then
    return active_scene.on_enter()
  end
end)

local on_j = loop.async(function()
  if active_scene.exists() then
    return active_scene.on_j()
  end
end)

local on_k = loop.async(function()
  if active_scene.exists() then
    return active_scene.on_k()
  end
end)

local win_enter = loop.async(function()
  if not active_scene.exists() and live_blame_setting:get('enabled') then
    live_blame:desync_all()
  end
  if active_scene.exists() then
    active_scene.keep_focused()
    return
  end
end)

local buf_enter = loop.async(function()
  live_gutter:resync()
end)

local buf_win_enter = loop.async(function()
  if active_scene.exists() then
    active_scene.destroy()
  end
  live_gutter:attach()
end)

local buf_win_leave = loop.async(function()
  -- Running the loop.await_fast_event to create a bit of time in between
  -- old buffer leaving the window and new buffer entering.
  loop.await_fast_event()
  -- After this call buf_win_enter should fire, where window will be destroyed.
  if active_scene.exists() then
    active_scene.destroy()
  end
end)

local buf_wipeout = loop.async(function()
  live_gutter:detach()
end)

local cursor_hold = loop.async(function()
  if live_blame_setting:get('enabled') then
    live_blame:sync()
  end
end)

local cursor_moved = loop.async(function()
  live_blame:desync()
end)

local insert_enter = loop.async(function()
  live_blame:desync(true)
end)

local colorscheme = loop.async(function()
  hls_setting:for_each(function(hl, color)
    highlight.define(hl, color)
  end)
end)

local hunk_up = loop.async(function()
  if active_scene.exists() then
    active_scene.navigate('up')
    return
  end
  buffer_hunks:move_up()
end)

local hunk_down = loop.async(function()
  if active_scene.exists() then
    active_scene.navigate('down')
    return
  end
  buffer_hunks:move_down()
end)

local buffer_hunk_reset = loop.async(function()
  buffer_hunks:cursor_reset()
end)

local buffer_reset = loop.async(function()
  if active_scene.exists() then
    active_scene.git_reset()
    return
  end
  buffer_hunks:reset_all()
end)

local buffer_stage = loop.async(function()
  if active_scene.exists() then
    active_scene.git_stage()
    return
  end
  buffer_hunks:stage_all()
end)

local buffer_unstage = loop.async(function()
  if active_scene.exists() then
    active_scene.git_unstage()
    return
  end
  buffer_hunks:unstage_all()
end)

local stage_all = loop.async(function()
  git:stage()
  if active_scene.exists() then
    active_scene.refresh()
    return
  end
end)

local unstage_all = loop.async(function()
  git:unstage()
  if active_scene.exists() then
    active_scene.refresh()
    return
  end
end)

local buffer_hunk_stage = loop.async(function()
  buffer_hunks:cursor_stage()
end)

local buffer_hunk_preview = loop.async(function()
  active_scene.hunk_scene()
end)

local buffer_hunk_staged_preview = loop.async(function()
  active_scene.staged_hunk_scene()
end)

local buffer_diff_preview = loop.async(function()
  active_scene.diff_scene()
end)

local buffer_diff_staged_preview = loop.async(function()
  active_scene.staged_diff_scene()
end)

local buffer_history_preview = loop.async(function()
  active_scene.history_scene()
end)

local buffer_blame_preview = loop.async(function()
  active_scene.line_blame_scene()
end)

local project_diff_preview = loop.async(function()
  active_scene.project_diff_scene()
end)

local project_hunks_preview = loop.async(function()
  active_scene.project_hunks_scene()
end)

local buffer_gutter_blame_preview = loop.async(function()
  active_scene.gutter_blame_scene()
end)

local toggle_diff_preference = loop.async(function()
  active_scene.toggle_diff_preference()
end)

local project_hunks_qf = loop.async(function()
  project_hunks_list:show_as_quickfix(project_hunks_list:fetch())
end)

local toggle_buffer_blames = loop.async(function()
  local blames_enabled = live_blame_setting:get('enabled')
  if blames_enabled then
    live_blame:desync_all()
  else
    live_blame:sync()
  end
  live_blame_setting:set('enabled', not blames_enabled)
end)

local toggle_buffer_hunks = loop.async(function()
  local hunks_enabled = live_gutter_setting:get('enabled')
  live_gutter_setting:set('enabled', not hunks_enabled)
  live_gutter:resync()
end)

local enable_tracing = loop.async(function()
  env.set('DEBUG', true)
end)

local disable_tracing = loop.async(function()
  env.set('DEBUG', false)
end)

local initialize_necessary_features = loop.async(function()
  live_gutter:attach()
  if live_blame_setting:get('enabled') then
    live_blame:sync()
  end
end)

local function command_list(...)
  return command:list(...)
end

local function execute_command(...)
  command:execute(...)
end

local function version()
  return versioning:current()
end

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
  highlight.register_module(function()
    sign.register_module()
  end)
  autocmd.register_module()
end

local function register_autocmds()
  autocmd.on('BufEnter', 'buf_enter()')
  autocmd.on('WinEnter', 'win_enter()')
  autocmd.on('BufWinEnter', 'buf_win_enter()')
  autocmd.on('BufWinLeave', 'buf_win_leave()')
  autocmd.on('BufWipeout', 'buf_wipeout()')
  autocmd.on('CursorHold', 'cursor_hold()')
  autocmd.on('CursorMoved', 'cursor_moved()')
  autocmd.on('InsertEnter', 'insert_enter()')
  autocmd.on('ColorScheme', 'colorscheme()')
end

local function configure_settings(config)
  local settings = config and config.settings or {}
  hls_setting:assign(settings.hls)
  live_blame_setting:assign(settings.live_blame)
  live_gutter_setting:assign(settings.live_gutter)
  scene_setting:assign(settings.scene)
  signs_setting:assign(settings.signs)
  symbols_setting:assign(settings.symbols)
end

local function define_keymaps(config)
  local keymaps = config and config.keymaps or {}
  keymap.define(keymaps)
end

local setup = function(config)
  if not versioning:is_neovim_compatible() then
    return
  end
  define_keymaps(config)
  configure_settings(config)
  setup_commands()
  register_modules()
  register_autocmds()
  initialize_necessary_features()
end

return {
  setup = setup,
  version = version,
  prevent_default = prevent_default,
  buf_enter = buf_enter,
  win_enter = win_enter,
  buf_win_enter = buf_win_enter,
  buf_win_leave = buf_win_leave,
  buf_wipeout = buf_wipeout,
  cursor_hold = cursor_hold,
  cursor_moved = cursor_moved,
  insert_enter = insert_enter,
  on_enter = on_enter,
  on_j = on_j,
  on_k = on_k,
  colorscheme = colorscheme,
  execute_command = execute_command,
  command_list = command_list,
  hunk_up = hunk_up,
  hunk_down = hunk_down,
  stage_all = stage_all,
  unstage_all = unstage_all,
  buffer_hunk_reset = buffer_hunk_reset,
  buffer_reset = buffer_reset,
  buffer_stage = buffer_stage,
  buffer_unstage = buffer_unstage,
  buffer_hunk_stage = buffer_hunk_stage,
  buffer_hunk_staged_preview = buffer_hunk_staged_preview,
  buffer_hunk_preview = buffer_hunk_preview,
  buffer_diff_preview = buffer_diff_preview,
  buffer_diff_staged_preview = buffer_diff_staged_preview,
  buffer_history_preview = buffer_history_preview,
  buffer_blame_preview = buffer_blame_preview,
  buffer_gutter_blame_preview = buffer_gutter_blame_preview,
  project_hunks_qf = project_hunks_qf,
  project_diff_preview = project_diff_preview,
  project_hunks_preview = project_hunks_preview,
  enable_tracing = enable_tracing,
  disable_tracing = disable_tracing,
  toggle_buffer_blames = toggle_buffer_blames,
  toggle_buffer_hunks = toggle_buffer_hunks,
  toggle_diff_preference = toggle_diff_preference,
  settings = {
    scene = scene_setting,
    hls = hls_setting,
    symbols = symbols_setting,
    signs = signs_setting,
    live_blame = live_blame_setting,
  },
}
