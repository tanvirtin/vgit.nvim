local Interface = require('vgit.Interface')
local localization = require('vgit.localization')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local sign = require('vgit.sign')
local t = localization.translate

local vim = vim

local PreviewPopup = {}
PreviewPopup.__index = PreviewPopup

local state = Interface.new({
    priority = 10,
    horizontal_window = {
        title = t('preview/horizontal'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    current_window = {
        title = t('preview/current'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    previous_window = {
        title = t('preview/previous'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    signs = {
        add = 'VGitViewSignAdd',
        remove = 'VGitViewSignRemove',
    },
})

local function setup(config)
    state:assign(config)
end

local function global_width()
    return vim.o.columns
end

local function global_height()
    return vim.o.lines
end

local function colorize_buf(lnum_changes, callback)
    for i = 1, #lnum_changes do
        local datum = lnum_changes[i]
        sign.place(callback(datum), datum.lnum, state:get('signs')[datum.type], state:get('priority'))
    end
end

local function create_horizontal_widget(opts)
    local height = math.ceil(global_height() - 4)
    local width = math.ceil(global_width() * 0.8)
    local col = math.ceil((global_width() - width) / 2) - 1
    return Widget.new({
        preview = View.new({
            filetype = opts.filetype,
            title = state:get('horizontal_window').title,
            border = state:get('horizontal_window').border,
            border_hl = state:get('horizontal_window').border_hl,
            border_focus_hl = state:get('horizontal_window').border_focus_hl,
            win_options = {
                ['cursorline'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col,
            },
        }),
    }, {
        name = opts.name,
    })
end

local function create_vertical_widget(opts)
    local height = math.ceil(global_height() - 4)
    local width = math.ceil(global_width() * 0.485)
    local col = math.ceil((global_width() - (width * 2)) / 2) - 1
    return Widget.new({
        previous = View.new({
            filetype = opts.filetype,
            title = state:get('previous_window').title,
            border = state:get('previous_window').border,
            border_hl = state:get('previous_window').border_hl,
            border_focus_hl = state:get('previous_window').border_focus_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col,
            },
        }),
        current = View.new({
            filetype = opts.filetype,
            title = state:get('current_window').title,
            border = state:get('current_window').border,
            border_hl = state:get('current_window').border_hl,
            border_focus_hl = state:get('current_window').border_focus_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col + width + 2,
            },
        }),
    }, {
        name = opts.name,
    })
end

local function new(opts)
    return setmetatable({
        vertical_widget = create_vertical_widget(opts),
        horizontal_widget = create_horizontal_widget(opts),
        layout_type = opts.layout_type,
        data = nil,
        err = nil,
    }, PreviewPopup)
end

function PreviewPopup:get_name()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    return widget:get_name()
end

function PreviewPopup:get_data()
    return self.data
end

function PreviewPopup:get_preview_win_ids()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
        return {
            widget:get_views().previous:get_win_id(),
            widget:get_views().current:get_win_id(),
        }
    end
    return { widget:get_views().preview:get_win_id() }
end

function PreviewPopup:get_win_ids()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    return widget:get_win_ids()
end

function PreviewPopup:set_loading(value)
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:set_loading(value)
    return self
end

function PreviewPopup:set_error(value)
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:set_error(value)
    return self
end

function PreviewPopup:is_preview_focused()
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

function PreviewPopup:set_cursor(row, col)
    if self.layout_type == 'vertical' then
        self.vertical_widget:get_views().previous:set_cursor(row, col)
        self.vertical_widget:get_views().current:set_cursor(row, col)
    else
        self.horizontal_widget:get_views().preview:set_cursor(row, col)
    end
    return self
end

function PreviewPopup:reposition_cursor(lnum)
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
            vim.cmd('norm! zz')
            break
        end
    end
end

function PreviewPopup:mount()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:mount(true)
    return self
end

function PreviewPopup:unmount()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:unmount()
    return self
end

function PreviewPopup:render()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    local err, data = self.err, self.data
    if err then
        widget:set_error(true)
        return self
    end
    if data then
        if self.layout_type == 'horizontal' then
            local views = widget:get_views()
            views.preview:set_lines(data.lines)
            colorize_buf(data.lnum_changes, function()
                return views.preview:get_buf()
            end)
        else
            local views = widget:get_views()
            views.previous:set_lines(data.previous_lines)
            views.current:set_lines(data.current_lines)
            colorize_buf(data.lnum_changes, function(datum)
                return views[datum.buftype]:get_buf()
            end)
        end
    end
    return self
end

return {
    new = new,
    setup = setup,
}
