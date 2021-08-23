local Object = require('plenary.class')
local painter = require('vgit.painter')
local dimensions = require('vgit.dimensions')
local Interface = require('vgit.Interface')
local localization = require('vgit.localization')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local t = localization.translate

local state = Interface:new({
    priority = 10,
    signs = {
        add = 'VGitViewSignAdd',
        remove = 'VGitViewSignRemove',
    },
    indicator = {
        hl = 'VGitIndicator',
    },
    horizontal_window = {
        title = t('diff/horizontal'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    current_window = {
        title = t('diff/current'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    previous_window = {
        title = t('diff/previous'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    table_window = {
        title = t('diff/table'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
})

local function create_horizontal_widget()
    local height = math.ceil(dimensions.global_height() - 3)
    local preview_width = math.ceil(dimensions.global_width() * 0.77) - 2
    local table_width = math.ceil(dimensions.global_width() * 0.20)
    local col = math.ceil((dimensions.global_width() - (preview_width + table_width)) / 2)
    local row = math.ceil((dimensions.global_height() - height) / 2) - 1
    local views = {
        preview = View:new({
            border = state:get('horizontal_window').border,
            border_hl = state:get('horizontal_window').border_hl,
            border_focus_hl = state:get('horizontal_window').border_focus_hl,
            title = state:get('horizontal_window').title,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = preview_width,
                height = height,
                row = row,
                col = col + table_width + 2,
            },
        }),
        table = View:new({
            title = state:get('table_window').title,
            border = state:get('table_window').border,
            border_hl = state:get('table_window').border_hl,
            border_focus_hl = state:get('table_window').border_focus_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = table_width,
                height = height,
                row = row,
                col = col,
            },
        }),
    }
    return Widget:new(views)
end

local function create_vertical_widget()
    local height = math.ceil(dimensions.global_height() - 12)
    local width = math.ceil(dimensions.global_width() * 0.5) - 2
    local col = math.ceil((dimensions.global_width() - (width * 2)) / 2) - 1
    local views = {
        previous = View:new({
            border = state:get('previous_window').border,
            border_hl = state:get('previous_window').border_hl,
            border_focus_hl = state:get('previous_window').border_focus_hl,
            title = state:get('previous_window').title,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
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
        current = View:new({
            title = state:get('current_window').title,
            border = state:get('current_window').border,
            border_hl = state:get('current_window').border_hl,
            border_focus_hl = state:get('current_window').border_focus_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
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
        table = View:new({
            title = state:get('table_window').title,
            border = state:get('table_window').border,
            border_hl = state:get('table_window').border_hl,
            border_focus_hl = state:get('table_window').border_focus_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width * 2 + 2,
                height = 7,
                row = height + 3,
                col = col,
            },
        }),
    }
    return Widget:new(views)
end

local DiffPopup = Object:extend()

function DiffPopup:setup(config)
    state:assign(config)
end

function DiffPopup:new(opts)
    return setmetatable({
        vertical_widget = create_vertical_widget(),
        horizontal_widget = create_horizontal_widget(),
        layout_type = opts.layout_type,
        diff_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/diff'),
        selected = 1,
        data = nil,
        err = nil,
    }, DiffPopup)
end

function DiffPopup:get_data()
    return self.data
end

function DiffPopup:get_preview_win_ids()
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

function DiffPopup:get_win_ids()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    return widget:get_win_ids()
end

function DiffPopup:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
end

function DiffPopup:set_loading(value)
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
        widget:get_views().previous:set_loading(value)
        widget:get_views().current:set_loading(value)
    else
        widget:get_views().preview:set_loading(value)
    end
    return self
end

function DiffPopup:set_error(value)
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:set_error(value)
    return self
end

function DiffPopup:is_preview_focused()
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

function DiffPopup:reposition_cursor(selected)
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:get_views().table:set_cursor(selected + 1, 0)
    return self
end

function DiffPopup:mount()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:mount(true)
    widget:set_loading(true)
    widget:get_views().table:focus()
    widget:get_views().table:add_keymap('<enter>', string.format('_change_diff(%s)', widget:get_parent_buf()))
    return self
end

function DiffPopup:unmount()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:unmount()
    return self
end

function DiffPopup:render()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    local views = widget:get_views()
    local table = views.table
    local err, data = self.err, self.data
    widget:clear()
    if err then
        if err[1] == 'File not found' then
            local changed_files = data.changed_files
            local warning_text = t('diff/file_not_found')
            if self.layout_type == 'horizontal' then
                views.preview:set_cursor(1, 0):set_centered_text(warning_text)
            else
                views.previous:set_cursor(1, 0):set_centered_text(warning_text)
                views.current:set_cursor(1, 0):set_centered_text(warning_text)
            end
            local rows = {}
            for i = 1, #changed_files do
                local file = changed_files[i]
                rows[#rows + 1] = {
                    file.filename or '',
                    file.status or '',
                }
            end
            table:create_table({ 'Filename', 'Status' }, rows)
            table:add_indicator(self.selected, self.diff_namespace, state:get('indicator').hl)
            return
        end
        widget:get_views().table:remove_keymap('<enter>')
        widget:set_error(true)
        return self
    elseif data then
        local changed_files = data.changed_files
        local diff_change = data.diff_change
        local filetype = data.filetype
        if self.layout_type == 'horizontal' then
            views.preview:set_cursor(1, 0):set_lines(diff_change.lines):set_filetype(filetype)
            painter.draw_changes(function()
                return views.preview:get_buf()
            end, diff_change.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        else
            views.previous:set_cursor(1, 0):set_lines(diff_change.previous_lines):set_filetype(filetype)
            views.current:set_cursor(1, 0):set_lines(diff_change.current_lines):set_filetype(filetype)
            painter.draw_changes(function(datum)
                return views[datum.buftype]:get_buf()
            end, diff_change.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        end
        local rows = {}
        for i = 1, #changed_files do
            local file = changed_files[i]
            rows[#rows + 1] = {
                file.filename or '',
                file.status or '',
            }
        end
        table:create_table({ 'Filename', 'Status' }, rows)
        table:add_indicator(self.selected, self.diff_namespace, state:get('indicator').hl)
    else
        table:set_centered_text(t('diff/no_changes'))
        table:remove_keymap('<enter>')
    end
    return self
end

return DiffPopup
