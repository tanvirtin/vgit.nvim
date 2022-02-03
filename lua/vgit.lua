local renderer = require('vgit.core.renderer')
local console = require('vgit.core.console')
local env = require('vgit.core.env')
local hls_setting = require('vgit.settings.hls')
local authorship_code_lens_setting = require(
  'vgit.settings.authorship_code_lens'
)
local live_blame_setting = require('vgit.settings.live_blame')
local live_gutter_setting = require('vgit.settings.live_gutter')
local scene_setting = require('vgit.settings.scene')
local project_diff_preview_setting = require(
  'vgit.settings.project_diff_preview'
)
local signs_setting = require('vgit.settings.signs')
local loop = require('vgit.core.loop')
local symbols_setting = require('vgit.settings.symbols')
local keymap = require('vgit.core.keymap')
local highlight = require('vgit.core.highlight')
local sign = require('vgit.core.sign')
local Command = require('vgit.Command')
local Navigation = require('vgit.Navigation')
local NavigationMarker = require('vgit.NavigationMarker')
local GitStore = require('vgit.GitStore')
local autocmd = require('vgit.core.autocmd')
local LiveGutter = require('vgit.features.LiveGutter')
local AuthorshipCodeLens = require('vgit.features.AuthorshipCodeLens')
local LiveBlame = require('vgit.features.LiveBlame')
local ProjectHunksList = require('vgit.features.ProjectHunksList')
local BufferHunks = require('vgit.features.BufferHunks')
local Git = require('vgit.cli.Git')
local Versioning = require('vgit.core.Versioning')
local active_screen = require('vgit.ui.active_screen')

local versioning = Versioning:new()
local git = Git:new()
local command = Command:new()
local navigation = Navigation:new()
local navigation_marker = NavigationMarker:new()
local git_store = GitStore:new()
local live_gutter = LiveGutter:new(git_store, versioning)
local live_blame = LiveBlame:new(git_store, versioning)
local authorship_code_lens = AuthorshipCodeLens:new(git_store, versioning)
local buffer_hunks = BufferHunks:new(
  git_store,
  versioning,
  navigation,
  navigation_marker
)
local project_hunks_list = ProjectHunksList:new(versioning)

active_screen.inject(buffer_hunks, navigation, git_store)

local keys = {
  enter = loop.async(function()
    if active_screen.exists() then
      return active_screen.keypress('<enter>')
    end
  end),
  j = loop.async(function()
    if active_screen.exists() then
      return active_screen.keypress('j')
    end
  end),
  k = loop.async(function()
    if active_screen.exists() then
      return active_screen.keypress('k')
    end
  end),
  prevent_default = function() end,
}

local win_enter = loop.async(function()
  if not active_screen.exists() then
    live_blame:desync_all()
  end
  if active_screen.exists() then
    return active_screen.keep_focused()
  end
end)

local buf_enter = loop.async(function()
  live_gutter:resync()
end)

local buf_read = loop.async(function()
  live_gutter:attach()
  authorship_code_lens:sync()
end)

local buf_new_file = loop.async(function()
  live_gutter:attach()
end)

local buf_write_post = loop.async(function()
  live_gutter:attach()
end)

local buf_win_enter = loop.async(function()
  if active_screen.exists() then
    return active_screen.destroy()
  end
end)

local buf_win_leave = loop.async(function()
  -- Running the loop.await_fast_event to create a bit of time in between
  -- old buffer leaving the window and new buffer entering.
  loop.await_fast_event()
  -- After this call buf_win_enter should fire, where window will be destroyed.
  if active_screen.exists() then
    return active_screen.destroy()
  end
end)

local cursor_hold = loop.async(function()
  live_blame:sync()
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
  if active_screen.exists() then
    return active_screen.action('navigate', 'up')
  end
  buffer_hunks:move_up()
end)

local hunk_down = loop.async(function()
  if active_screen.exists() then
    return active_screen.action('navigate', 'down')
  end
  buffer_hunks:move_down()
end)

local buffer_hunk_reset = loop.async(function()
  buffer_hunks:cursor_reset()
end)

local buffer_reset = loop.async(function()
  if active_screen.exists() then
    return active_screen.action('git_reset')
  end
  buffer_hunks:reset_all()
end)

local buffer_stage = loop.async(function()
  if active_screen.exists() then
    return active_screen.action('git_stage')
  end
  buffer_hunks:stage_all()
end)

local buffer_unstage = loop.async(function()
  if active_screen.exists() then
    return active_screen.action('git_unstage')
  end
  buffer_hunks:unstage_all()
end)

local stage_all = loop.async(function()
  git:stage()
  if active_screen.exists() then
    return active_screen.action('refresh')
  end
end)

local unstage_all = loop.async(function()
  git:unstage()
  if active_screen.exists() then
    return active_screen.action('refresh')
  end
end)

local reset_all = loop.async(function()
  local decision = console.input(
    'Are you sure you want to discard all changes? (y/N) '
  ):lower()
  if decision ~= 'yes' and decision ~= 'y' then
    return
  end
  git:discard()
  if active_screen.exists() then
    return active_screen.action('refresh')
  end
end)

local buffer_hunk_stage = loop.async(function()
  buffer_hunks:cursor_stage()
end)

local buffer_hunk_preview = loop.async(function()
  active_screen.activate('diff_hunk_screen')
end)

local buffer_hunk_staged_preview = loop.async(function()
  active_screen.activate('staged_hunk_screen')
end)

local buffer_diff_preview = loop.async(function()
  active_screen.activate('diff_screen')
end)

local buffer_diff_staged_preview = loop.async(function()
  active_screen.activate('staged_diff_screen')
end)

local buffer_history_preview = loop.async(function()
  active_screen.activate('history_screen')
end)

local buffer_blame_preview = loop.async(function()
  active_screen.activate('line_blame_screen')
end)

local project_diff_preview = loop.async(function()
  active_screen.activate('project_diff_screen')
end)

local project_hunks_preview = loop.async(function()
  active_screen.activate('project_hunks_screen')
end)

local buffer_gutter_blame_preview = loop.async(function()
  active_screen.activate('gutter_blame_screen')
end)

local project_hunks_qf = loop.async(function()
  project_hunks_list:show_as_quickfix(project_hunks_list:fetch())
end)

local toggle_diff_preference = loop.async(function()
  active_screen.toggle_diff_preference()
end)

local toggle_live_blame = loop.async(function()
  local blames_enabled = live_blame_setting:get('enabled')
  live_blame_setting:set('enabled', not blames_enabled)
  live_blame:resync()
end)

local toggle_live_gutter = loop.async(function()
  local live_gutter_enabled = live_gutter_setting:get('enabled')
  live_gutter_setting:set('enabled', not live_gutter_enabled)
  live_gutter:resync()
end)

local toggle_authorship_code_lens = loop.async(function()
  local authorship_code_lens_enabled = authorship_code_lens_setting:get(
    'enabled'
  )
  authorship_code_lens_setting:set('enabled', not authorship_code_lens_enabled)
  authorship_code_lens:resync()
end)

local enable_tracing = loop.async(function()
  env.set('DEBUG', true)
end)

local disable_tracing = loop.async(function()
  env.set('DEBUG', false)
end)

local initialize_necessary_features = loop.async(function()
  live_gutter:attach()
  live_blame:sync()
  authorship_code_lens:sync()
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

local function help()
  vim.cmd('h vgit')
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
  renderer.register_module()
end

local function register_autocmds()
  autocmd.on('BufEnter', 'buf_enter()')
  autocmd.on('BufRead', 'buf_read()')
  autocmd.on('BufNewFile', 'buf_new_file()')
  autocmd.on('BufWritePost', 'buf_write_post()')
  autocmd.on('WinEnter', 'win_enter()')
  autocmd.on('BufWinEnter', 'buf_win_enter()')
  autocmd.on('BufWinLeave', 'buf_win_leave()')
  autocmd.on('CursorHold', 'cursor_hold()')
  autocmd.on('CursorMoved', 'cursor_moved()')
  autocmd.on('InsertEnter', 'insert_enter()')
  autocmd.on('ColorScheme', 'colorscheme()')
end

local function configure_settings(config)
  local settings = config and config.settings or {}
  hls_setting:assign(settings.hls)
  live_blame_setting:assign(settings.live_blame)
  authorship_code_lens_setting:assign(settings.authorship_code_lens)
  live_gutter_setting:assign(settings.live_gutter)
  scene_setting:assign(settings.scene)
  signs_setting:assign(settings.signs)
  symbols_setting:assign(settings.symbols)
  project_diff_preview_setting:assign(settings.project_diff_preview)
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
  help = help,
  h = help,
  version = version,
  buf_enter = buf_enter,
  buf_read = buf_read,
  buf_new_file = buf_new_file,
  buf_write_post = buf_write_post,
  win_enter = win_enter,
  buf_win_enter = buf_win_enter,
  buf_win_leave = buf_win_leave,
  cursor_hold = cursor_hold,
  cursor_moved = cursor_moved,
  insert_enter = insert_enter,
  colorscheme = colorscheme,
  execute_command = execute_command,
  command_list = command_list,
  hunk_up = hunk_up,
  hunk_down = hunk_down,
  stage_all = stage_all,
  unstage_all = unstage_all,
  reset_all = reset_all,
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
  toggle_live_gutter = toggle_live_gutter,
  toggle_live_blame = toggle_live_blame,
  toggle_authorship_code_lens = toggle_authorship_code_lens,
  toggle_diff_preference = toggle_diff_preference,
  keys = keys,
  settings = {
    screen = scene_setting,
    hls = hls_setting,
    symbols = symbols_setting,
    signs = signs_setting,
    live_blame = live_blame_setting,
  },
  -- @deprecated
  toggle_buffer_hunks = toggle_live_gutter,
  toggle_buffer_blames = toggle_live_blame,
}
