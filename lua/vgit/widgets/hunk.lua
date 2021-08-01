local State = require('vgit.State')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local sign = require('vgit.sign')

local vim = vim

local M = {}

M.state = State.new({
    priority = 10,
    window = {
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
    },
    signs = {
        add = 'VGitViewSignAdd',
        remove = 'VGitViewSignRemove',
    },
})

M.setup = function(config)
    M.state:assign(config)
end

M.render = function(hunk, filetype)
    local lines = hunk.diff
    local trimmed_lines = {}
    local added_lines = {}
    local removed_lines = {}
    for index, line in pairs(lines) do
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            added_lines[#added_lines + 1] = index
        elseif first_letter == '-' then
            removed_lines[#removed_lines + 1] = index
        end
        trimmed_lines[#trimmed_lines + 1] = line:sub(2, #line)
    end
    local view = View.new({
        filetype = filetype,
        lines = trimmed_lines,
        border = M.state:get('window').border,
        border_hl = M.state:get('window').border_hl,
        win_options = { ['cursorline'] = true },
        window_props = {
            style = 'minimal',
            relative = 'cursor',
            height = #lines,
            width = vim.api.nvim_get_option('columns'),
            row = 0,
            col = 0,
        },
    })
    local widget = Widget.new({ view }, 'hunk')
    widget:render(true)
    view:set_lines(trimmed_lines)
    for i = 1, #added_lines do
        local lnum = added_lines[i]
        sign.place(view:get_buf(), lnum, M.state:get('signs')['add'], M.state:get('priority'))
    end
    for i = 1, #removed_lines do
        local lnum = removed_lines[i]
        sign.place(view:get_buf(), lnum, M.state:get('signs')['remove'], M.state:get('priority'))
    end
    return widget
end

return M
