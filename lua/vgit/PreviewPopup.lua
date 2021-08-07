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
    }, PreviewPopup)
end

function PreviewPopup:get_name()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    return widget:get_name()
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
