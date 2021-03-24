local M = {}

local state = {
    group = 'git',
    types = {
        add = {
            hl = 'GitAdd',
            color = '#d7ffaf',
            text = ' '
        },
        remove = {
            hl = 'GitRemove',
            color = '#e95678',
            text = ' '
        },
        change = {
            hl = 'GitChange',
            color = '#7AA6DA',
            text = ' '
        },
    },
    priority = 10
}

M.initialize = function()
    for key, type in pairs(state.types) do
        vim.cmd('hi ' .. state.types[key].hl .. ' guibg=' .. state.types[key].color)
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
