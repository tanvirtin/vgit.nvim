local State = require('vgit.State')

local M = {}

M.state = State.new({
    signs = {
        VGitViewSignAdd = {
            name = 'VGitViewSignAdd',
            line_hl = 'VGitViewSignAdd',
            text_hl = 'VGitViewTextAdd',
            text = '+'
        },
        VGitViewSignRemove = {
            name = 'VGitViewSignRemove',
            line_hl = 'VGitViewSignRemove',
            text_hl = 'VGitViewTextRemove',
            text = '-'
        },
        VGitSignAdd = {
            name = 'VGitSignAdd',
            text_hl = 'VGitSignAdd',
            line_hl = nil,
            text = '│'
        },
        VGitSignRemove = {
            name = 'VGitSignRemove',
            text_hl = 'VGitSignRemove',
            line_hl = nil,
            text = '│'
        },
        VGitSignChange = {
            name = 'VGitSignChange',
            text_hl = 'VGitSignChange',
            line_hl = nil,
            text = '│'
        },
    }
})

M.setup = function(config)
    M.state:assign(config)
    for _, action in pairs(M.state.current.signs) do
        M.define(action)
    end
end

M.define = function(config)
    vim.fn.sign_define(config.name, {
        text = config.text,
        texthl = config.text_hl,
        linehl = config.line_hl,
    })
end

return M
