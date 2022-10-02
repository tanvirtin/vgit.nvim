local env = require('vgit.core.env')
local loop = require('vgit.core.loop')
local sign = require('vgit.core.sign')
local Git = require('vgit.git.cli.Git')
local Command = require('vgit.Command')
local event = require('vgit.core.event')
local keymap = require('vgit.core.keymap')
local autocmd = require('vgit.core.autocmd')
local console = require('vgit.core.console')
local renderer = require('vgit.core.renderer')
local authorship_code_lens_setting = require(
  'vgit.settings.authorship_code_lens'
)
local project_diff_preview_setting = require(
  'vgit.settings.project_diff_preview'
)
local hls_setting = require('vgit.settings.hls')
local git_setting = require('vgit.settings.git')
local highlight = require('vgit.core.highlight')
local versioning = require('vgit.core.versioning')
local Hunks = require('vgit.features.buffer.Hunks')
local scene_setting = require('vgit.settings.scene')
local signs_setting = require('vgit.settings.signs')
local screen_manager = require('vgit.ui.screen_manager')
local symbols_setting = require('vgit.settings.symbols')
local diff_preview = require('vgit.settings.diff_preview')
local LiveBlame = require('vgit.features.buffer.LiveBlame')
local LiveGutter = require('vgit.features.buffer.LiveGutter')
local live_blame_setting = require('vgit.settings.live_blame')
local live_gutter_setting = require('vgit.settings.live_gutter')
local AuthorshipCodeLens = require('vgit.features.buffer.AuthorshipCodeLens')
local ProjectHunksQuickfix = require(
  'vgit.features.quickfix.ProjectHunksQuickfix'
)

local hunks = Hunks()
local command = Command()
local live_blame = LiveBlame()
local live_gutter = LiveGutter()
local authorship_code_lens = AuthorshipCodeLens()
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
  hunk_up = loop.async(function()
    hunks:move_up()

    if screen_manager.exists() then
      return screen_manager.dispatch_action('hunk_up')
    end
  end),

  hunk_down = loop.async(function()
    hunks:move_down()

    if screen_manager.exists() then
      return screen_manager.dispatch_action('hunk_down')
    end
  end),
}

local buffer = {
  hunk_reset = loop.async(function()
    hunks:cursor_reset()
  end),

  reset = loop.async(function()
    hunks:reset_all()
  end),

  stage = loop.async(function()
    hunks:stage_all()
  end),

  unstage = loop.async(function()
    hunks:unstage_all()
  end),

  hunk_stage = loop.async(function()
    hunks:cursor_stage()
  end),

  hunk_preview = loop.async(function()
    screen_manager.activate('diff_hunk_screen')
  end),

  hunk_staged_preview = loop.async(function()
    screen_manager.activate('diff_hunk_screen', {
      is_staged = true,
    })
  end),

  diff_preview = loop.async(function()
    screen_manager.activate('diff_screen')
  end),

  diff_staged_preview = loop.async(function()
    screen_manager.activate('diff_screen', {
      is_staged = true,
    })
  end),

  history_preview = loop.async(function()
    screen_manager.activate('history_screen')
  end),

  blame_preview = loop.async(function()
    screen_manager.activate('line_blame_screen')
  end),

  gutter_blame_preview = loop.async(function()
    screen_manager.activate('gutter_blame_screen')
  end),
}

local project = {
  stage_all = loop.async(function()
    Git():stage()
  end),

  unstage_all = loop.async(function()
    Git():unstage()
  end),

  reset_all = loop.async(function()
    local decision = console.input(
      'Are you sure you want to discard all tracked changes? (y/N) '
    ):lower()

    if decision ~= 'yes' and decision ~= 'y' then
      return
    end

    Git():reset_all()
  end),

  diff_preview = loop.async(function()
    screen_manager.activate('project_diff_screen')
  end),

  logs_preview = loop.async(function(...)
    screen_manager.activate('project_logs_screen', ...)
  end),

  stash_preview = loop.async(function(...)
    screen_manager.activate('project_stash_screen', ...)
  end),

  commits_preview = loop.async(function(...)
    screen_manager.activate('project_commits_screen', ...)
  end),

  hunks_preview = loop.async(function()
    screen_manager.activate('project_hunks_screen')
  end),

  hunks_staged_preview = loop.async(function()
    screen_manager.activate('project_hunks_screen', {
      is_staged = true,
    })
  end),

  hunks_qf = loop.async(function()
    project_hunks_quickfix:show()
  end),

  debug_preview = loop.async(function(...)
    screen_manager.activate('debug_screen', ...)
  end),
}

local checkout = loop.async(function(...)
  local err = Git():checkout({ ... })

  if err then
    console.debug.error(err).error(err)
  end
end)

local toggle_diff_preference = loop.async(function()
  screen_manager.toggle_diff_preference()
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

local toggle_tracing = loop.async(function()
  env.set('DEBUG', not env.get('DEBUG'))
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
  return versioning.current()
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

local function register_events()
  screen_manager.register_events()
  live_blame:register_events()
  live_gutter:register_events()
  authorship_code_lens:register_events()

  event.on('ColorScheme', function()
    hls_setting:for_each(function(hl, color)
      highlight.define(hl, color)
    end)
  end).on('ColorScheme', function()
    hls_setting:for_each(function(hl, color)
      highlight.define(hl, color)
    end)
  end)
end

local function configure_settings(config)
  local config_settings = config and config.settings or {}

  hls_setting:assign(config_settings.hls)
  diff_preview:assign(config_settings.diff_preview)
  live_blame_setting:assign(config_settings.live_blame)
  authorship_code_lens_setting:assign(config_settings.authorship_code_lens)
  live_gutter_setting:assign(config_settings.live_gutter)
  scene_setting:assign(config_settings.scene)
  signs_setting:assign(config_settings.signs)
  git_setting:assign(config_settings.git)
  symbols_setting:assign(config_settings.symbols)
  project_diff_preview_setting:assign(config_settings.project_diff_preview)
end

local function define_keymaps(config)
  local keymaps = config and config.keymaps or {}

  keymap.define(keymaps)
end

local setup = function(config)
  if not versioning.is_neovim_compatible() then
    return
  end

  define_keymaps(config)
  configure_settings(config)
  setup_commands()
  register_modules()
  register_events()
  initialize_necessary_features()
end

return {
  h = help,
  help = help,
  setup = setup,
  version = version,
  command_list = command_list,
  execute_command = execute_command,

  settings = settings,

  toggle_tracing = toggle_tracing,
  toggle_live_blame = toggle_live_blame,
  toggle_live_gutter = toggle_live_gutter,
  toggle_diff_preference = toggle_diff_preference,
  toggle_authorship_code_lens = toggle_authorship_code_lens,

  hunk_up = controls.hunk_up,
  hunk_down = controls.hunk_down,

  checkout = checkout,

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

  project_hunks_qf = project.hunks_qf,
  project_stage_all = project.stage_all,
  project_reset_all = project.reset_all,
  project_unstage_all = project.unstage_all,
  project_logs_preview = project.logs_preview,
  project_stash_preview = project.stash_preview,
  project_diff_preview = project.diff_preview,
  project_hunks_preview = project.hunks_preview,
  project_debug_preview = project.debug_preview,
  project_commits_preview = project.commits_preview,
  project_hunks_staged_preview = project.hunks_staged_preview,
}
