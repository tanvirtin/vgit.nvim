local highlight = require('git.highlight')

local M = {}

local state = {
    group = 'git',
    types = {
        add = {
            hl = 'GitAdd',
            bg = '#d7ffaf',
            fg = nil,
            text = ' '
        },
        remove = {
            hl = 'GitRemove',
            bg = '#e95678',
            fg = nil,
            text = ' '
        },
        change = {
            hl = 'GitChange',
            bg = '#7AA6DA',
            fg = nil,
            text = ' '
        },
    },
    priority = 10
}

M.initialize = function()
    for key, type in pairs(state.types) do
        highlight.add(state.types[key].hl, state.types[key])
        vim.fn.sign_define(type.hl, {
            text = type.text,
            texthl = type.hl
        })
    end
end

M.clear_all = function(callback)
    vim.schedule(function()
        vim.fn.sign_unplace(state.group)
        if type(callback) == 'function' then
            callback()
        end
    end)
end

M.tear_down = function()
    M.clear_all(function()
        state = nil
    end)
end

M.place = function(hunk)
    for lnum = hunk.start, hunk.finish do
        vim.schedule(function()
           vim.fn.sign_place(lnum, state.group, state.types[hunk.type].hl, hunk.filepath, {
               lnum = lnum,
               priority = state.priority,
           })
        end)
    end
end

return M
