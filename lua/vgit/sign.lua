local ImmutableInterface = require('vgit.ImmutableInterface')
local Interface = require('vgit.Interface')

local M = {}

M.constants = ImmutableInterface.new({
    ns = 'tanvirtin/vgit.nvim/hunk/signs',
})

M.state = Interface.new({
    VGitViewSignAdd = {
        name = 'VGitViewSignAdd',
        line_hl = 'VGitViewSignAdd',
        text_hl = 'VGitViewTextAdd',
        num_hl = nil,
        icon = nil,
        text = '+',
    },
    VGitViewSignRemove = {
        name = 'VGitViewSignRemove',
        line_hl = 'VGitViewSignRemove',
        text_hl = 'VGitViewTextRemove',
        num_hl = nil,
        icon = nil,
        text = '-',
    },
    VGitSignAdd = {
        name = 'VGitSignAdd',
        text_hl = 'VGitSignAdd',
        num_hl = nil,
        icon = nil,
        line_hl = nil,
        text = '┃',
    },
    VGitSignRemove = {
        name = 'VGitSignRemove',
        text_hl = 'VGitSignRemove',
        num_hl = nil,
        icon = nil,
        line_hl = nil,
        text = '┃',
    },
    VGitSignChange = {
        name = 'VGitSignChange',
        text_hl = 'VGitSignChange',
        num_hl = nil,
        icon = nil,
        line_hl = nil,
        text = '┃',
    },
})

M.setup = function(config)
    M.state:assign((config and config.signs) or config)
    for _, action in pairs(M.state.data) do
        M.define(action)
    end
end

M.define = function(config)
    vim.fn.sign_define(config.name, {
        text = config.text,
        texthl = config.text_hl,
        numhl = config.num_hl,
        icon = config.icon,
        linehl = config.line_hl,
    })
end

M.place = function(buf, lnum, type, priority)
    vim.fn.sign_place(lnum, string.format('%s/%s', M.constants:get('ns'), buf), type, buf, {
        id = lnum,
        lnum = lnum,
        priority = priority,
    })
end

M.unplace = function(buf)
    vim.fn.sign_unplace(string.format('%s/%s', M.constants:get('ns'), buf))
end

M.get = function(buf, lnum)
    local signs = vim.fn.sign_getplaced(buf, {
        group = string.format('%s/%s', M.constants:get('ns'), buf),
        id = lnum,
    })[1].signs
    local result = {}
    for i = 1, #signs do
        local sign = signs[i]
        result[i] = sign.name
    end
    return result
end

return M
