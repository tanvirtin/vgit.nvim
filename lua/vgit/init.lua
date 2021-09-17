local git = require('vgit.git')
local themes = require('vgit.themes')
local layouts = require('vgit.layouts')
local renderer = require('vgit.renderer')
local highlight = require('vgit.highlight')
local events = require('vgit.events')
local sign = require('vgit.sign')
local key_mapper = require('vgit.key_mapper')
local controller_store = require('vgit.stores.controller_store')
local render_store = require('vgit.stores.render_store')
local logger = require('vgit.logger')
local dimensions = require('vgit.dimensions')
local view_controller = require('vgit.controllers.view_controller')
local actions_controller = require('vgit.controllers.actions_controller')
local events_controller = require('vgit.controllers.events_controller')
local settings_controller = require('vgit.controllers.settings_controller')
local internals_controller = require('vgit.controllers.internals_controller')

local M = {}

M = vim.tbl_extend('keep', M, view_controller)
M = vim.tbl_extend('keep', M, actions_controller)
M = vim.tbl_extend('keep', M, events_controller)
M = vim.tbl_extend('keep', M, settings_controller)
M = vim.tbl_extend('keep', M, internals_controller)

-- Submodules
M.renderer = renderer
M.events = events
M.highlight = highlight
M.themes = themes
M.layouts = layouts
M.dimensions = dimensions

M.setup = function(config)
    controller_store.setup(config)
    render_store.setup(config)
    events.setup()
    highlight.setup(config)
    sign.setup(config)
    logger.setup(config)
    git.setup(config)
    key_mapper.setup(config)
    events.on('BufWinEnter', ':lua require("vgit")._buf_attach()')
    events.on('BufWinLeave', ':lua require("vgit")._buf_detach()')
    events.on('BufWritePost', ':lua require("vgit")._buf_update()')
    events.on('WinEnter', ':lua require("vgit")._keep_focused()')
    vim.cmd(
        string.format(
            'com! -nargs=+ %s %s',
            '-complete=customlist,v:lua.package.loaded.vgit._command_autocompletes',
            'VGit lua require("vgit")._run_command(<f-args>)'
        )
    )
end

return M
