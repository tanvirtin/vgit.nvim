local Object = require('plenary.class')
local painter = require('vgit.painter')
local dimensions = require('vgit.dimensions')
local Interface = require('vgit.Interface')
local View = require('vgit.View')
local Widget = require('vgit.Widget')

local state = Interface:new({
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

local HunkLensPopup = Object:extend()

function HunkLensPopup:setup(config)
    state:assign(config)
end

function HunkLensPopup:new(opts)
    return setmetatable({
        widget = Widget:new({
            View:new({
                border = state:get('window').border,
                border_hl = state:get('window').border_hl,
                win_options = { ['cursorline'] = true },
                window_props = {
                    style = 'minimal',
                    relative = 'cursor',
                    width = dimensions.global_width(),
                    row = 0,
                    col = 0,
                },
                filetype = opts.filetype,
            }),
        }, {
            popup = true,
        }),
        data = nil,
        err = nil,
    }, HunkLensPopup)
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

function HunkLensPopup:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
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
    local hunks = self.data.diff_change.hunks
    for i = 1, #hunks do
        local hunk = hunks[i]
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
    local widget = self.widget
    local err, data = self.err, self.data
    widget:clear()
    if err then
        self.widget:set_error(true)
        return self
    end
    if data then
        local views = self.widget:get_views()
        local v = views[1]
        v:set_lines(data.diff_change.lines)
        local new_width = #data.selected_hunk.diff
        if new_width ~= 0 then
            if new_width > v:get_min_height() then
                v:set_height(new_width)
            else
                v:set_height(v:get_min_height())
            end
        end
        painter.draw_changes(function()
            return v:get_buf()
        end, data.diff_change.lnum_changes, state:get(
            'signs'
        ), state:get(
            'priority'
        ))
    end
    return self
end

return HunkLensPopup
