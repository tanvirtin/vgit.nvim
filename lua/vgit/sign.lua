local State = require('vgit.State')

local M = {}

M.constants = {
    ns = 'tanvirtin/vgit.nvim/hunk/signs',
}

M.state = State.new({
    signs = {
        VGitViewSignAdd = {
            name = 'VGitViewSignAdd',
            line_hl = 'VGitViewSignAdd',
            text_hl = 'VGitViewTextAdd',
            text = '+',
        },
        VGitViewSignRemove = {
            name = 'VGitViewSignRemove',
            line_hl = 'VGitViewSignRemove',
            text_hl = 'VGitViewTextRemove',
            text = '-',
        },
        VGitSignAdd = {
            name = 'VGitSignAdd',
            text_hl = 'VGitSignAdd',
            num_hl = nil,
            line_hl = nil,
            text = '┃',
        },
        VGitSignRemove = {
            name = 'VGitSignRemove',
            text_hl = 'VGitSignRemove',
            num_hl = nil,
            line_hl = nil,
            text = '┃',
        },
        VGitSignChange = {
            name = 'VGitSignChange',
            text_hl = 'VGitSignChange',
            num_hl = nil,
            line_hl = nil,
            text = '┃',
        },
    },
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
        numhl = config.num_hl,
        linehl = config.line_hl,
    })
end

M.place = function(buf, lnum, type, priority)
    vim.fn.sign_place(lnum, string.format('%s/%s', M.constants.ns, buf), type, buf, {
        id = lnum,
        lnum = lnum,
        priority = priority,
    })
end

M.unplace = function(buf)
    vim.fn.sign_unplace(string.format('%s/%s', M.constants.ns, buf))
end

M.get = function(buf, lnum)
    local signs = vim.fn.sign_getplaced(buf, {
        group = string.format('%s/%s', M.constants.ns, buf),
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
