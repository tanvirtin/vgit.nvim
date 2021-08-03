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

local function parse_hunk_diff(diff)
    local lines = {}
    local added_lines = {}
    local removed_lines = {}
    for index, line in pairs(diff) do
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            added_lines[#added_lines + 1] = index
        elseif first_letter == '-' then
            removed_lines[#removed_lines + 1] = index
        end
        lines[#lines + 1] = line:sub(2, #line)
    end
    return lines, added_lines, removed_lines
end

local function create_widget(opts)
    local view = View.new({
        filetype = opts.filetype,
        lines = opts.lines,
        border = M.state:get('window').border,
        border_hl = M.state:get('window').border_hl,
        win_options = { ['cursorline'] = true },
        window_props = {
            style = 'minimal',
            relative = 'cursor',
            height = #opts.lines,
            width = vim.api.nvim_get_option('columns'),
            row = 0,
            col = 0,
        },
    })
    return Widget.new({ view }, 'hunk')
end

M.show = function(hunk, filetype)
    local lines, added_lines, removed_lines = parse_hunk_diff(hunk.diff)
    local widget = create_widget({
        lines = lines,
        filetype = filetype,
    })
    local view = widget:get_views()[1]
    view:set_lines(lines)
    for i = 1, #added_lines do
        sign.place(view:get_buf(), added_lines[i], M.state:get('signs')['add'], M.state:get('priority'))
    end
    for i = 1, #removed_lines do
        sign.place(view:get_buf(), removed_lines[i], M.state:get('signs')['remove'], M.state:get('priority'))
    end
    widget:render(true)
    return widget
end

return M
