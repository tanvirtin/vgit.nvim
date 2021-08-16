local Interface = require('vgit.Interface')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local sign = require('vgit.sign')

local vim = vim

local HunkPopup = {}
HunkPopup.__index = HunkPopup

local state = Interface.new({
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

local function setup(config)
    state:assign(config)
end

local function new(opts)
    return setmetatable({
        widget = Widget.new({
            View.new({
                border = state:get('window').border,
                border_hl = state:get('window').border_hl,
                win_options = { ['cursorline'] = true },
                window_props = {
                    style = 'minimal',
                    relative = 'cursor',
                    width = vim.api.nvim_get_option('columns'),
                    row = 0,
                    col = 0,
                },
                filetype = opts.filetype,
            }),
        }, {
            name = 'hunk',
            popup = true,
        }),
    }, HunkPopup)
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

function HunkPopup:get_win_ids()
    return self.widget:get_win_ids()
end

function HunkPopup:get_name()
    return self.widget:get_name()
end

function HunkPopup:set_loading(value)
    self.widget:set_loading(value)
    return self
end

function HunkPopup:set_error(value)
    self.widget:set_error(value)
    return self
end

function HunkPopup:mount()
    self.widget:mount(true)
    return self
end

function HunkPopup:unmount()
    self.widget:unmount()
    return self
end

function HunkPopup:render()
    local err, hunk = self.err, self.data
    if err then
        self.widget:set_error(true)
        return self
    end
    if hunk then
        local lines, added_lines, removed_lines = parse_hunk_diff(hunk.diff)
        local view = self.widget:get_views()[1]
        view:set_lines(lines)
        view:set_height(#lines)
        for i = 1, #added_lines do
            sign.place(view:get_buf(), added_lines[i], state:get('signs')['add'], state:get('priority'))
        end
        for i = 1, #removed_lines do
            sign.place(view:get_buf(), removed_lines[i], state:get('signs')['remove'], state:get('priority'))
        end
        self.widget:mount(true)
    end
    return self
end

return {
    new = new,
    setup = setup,
}
