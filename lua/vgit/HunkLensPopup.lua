local paint = require('vgit.paint')
local Interface = require('vgit.Interface')
local View = require('vgit.View')
local Widget = require('vgit.Widget')

local vim = vim

local HunkLensPopup = {}
HunkLensPopup.__index = HunkLensPopup

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
            name = 'hunk_lens',
            popup = true,
        }),
        data = {
            -- TODO: NEED TO BE A defined DTO
            lines = {},
            current_lines = {},
            previous_lines = {},
            hunk = { diff = {} },
            hunks = {},
            lnum_changes = {},
            marks = {},
        },
        err = nil,
    }, HunkLensPopup)
end

function HunkLensPopup:get_name()
    return self.widget:get_name()
end

function HunkLensPopup:get_data()
    return self.data
end

function HunkLensPopup:get_preview_win_ids()
    return { self.widget:get_views()[1]:get_win_id() }
end

function HunkLensPopup:get_win_ids()
    return self.widget:get_win_ids()
end

function HunkLensPopup:set_loading(value)
    self.widget:set_loading(value)
    return self
end

function HunkLensPopup:set_error(value)
    self.widget:set_error(value)
    return self
end

function HunkLensPopup:set_cursor(row, col)
    self.widget:get_views()[1]:set_cursor(row, col)
    return self
end

function HunkLensPopup:is_preview_focused()
    local preview_win_ids = self:get_preview_win_ids()
    local current_win_id = vim.api.nvim_get_current_win()
    for i = 1, #preview_win_ids do
        local win_id = preview_win_ids[i]
        if win_id == current_win_id then
            return true
        end
    end
    return false
end

function HunkLensPopup:reposition_cursor(lnum)
    local new_lines_added = 0
    for i = 1, #self.data.hunks do
        local hunk = self.data.hunks[i]
        local type = hunk.type
        local diff = hunk.diff
        local current_new_lines_added = 0
        if type == 'remove' then
            for _ = 1, #diff do
                current_new_lines_added = current_new_lines_added + 1
            end
        elseif type == 'change' then
            for j = 1, #diff do
                local line = diff[j]
                local line_type = line:sub(1, 1)
                if line_type == '-' then
                    current_new_lines_added = current_new_lines_added + 1
                end
            end
        end
        new_lines_added = new_lines_added + current_new_lines_added
        local start = hunk.start + new_lines_added
        local finish = hunk.finish + new_lines_added
        local padded_lnum = lnum + new_lines_added
        if padded_lnum >= start and padded_lnum <= finish then
            if type == 'remove' then
                self:set_cursor(start - current_new_lines_added + 1, 0)
            else
                self:set_cursor(start - current_new_lines_added, 0)
            end
            vim.cmd('norm! zt')
            break
        end
    end
end

function HunkLensPopup:mount()
    self.widget:mount(true)
    return self
end

function HunkLensPopup:unmount()
    self.widget:unmount()
    return self
end

function HunkLensPopup:render()
    local err, data = self.err, self.data
    if err then
        self.widget:set_error(true)
        return self
    end
    if data then
        local views = self.widget:get_views()
        local v = views[1]
        v:set_lines(data.lines)
        local new_width = #data.hunk.diff
        if new_width ~= 0 then
            if new_width > v:get_min_height() then
                v:set_height(new_width)
            else
                v:set_height(v:get_min_height())
            end
        end
        paint.changes(function()
            return v:get_buf()
        end, data.lnum_changes, state:get('signs'), state:get(
            'priority'
        ))
    end
    return self
end

return {
    new = new,
    setup = setup,
}
