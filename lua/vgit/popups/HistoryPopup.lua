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
        title = t('history/horizontal'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    current_window = {
        title = t('history/current'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    previous_window = {
        title = t('history/previous'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    table_window = {
        title = t('history/table'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
})

local function create_horizontal_widget(opts)
    local height = math.floor(dimensions.global_height() - 13)
    local width = math.floor(dimensions.global_width() * 0.9)
    local col = math.ceil((dimensions.global_width() - width) / 2)
    local views = {
        preview = View:new({
            filetype = opts.filetype,
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
                width = width,
                height = height,
                row = 1,
                col = col,
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
                width = width,
                height = 7,
                row = height + 3,
                col = col,
            },
        }),
    }
    return Widget:new(views)
end

local function create_vertical_widget(opts)
    local height = math.floor(dimensions.global_height() - 13)
    local width = math.floor((dimensions.global_width()) / 2) - 5
    local col = math.ceil((dimensions.global_width() - (width * 2)) / 2)
    local spacing = 2
    local views = {
        previous = View:new({
            filetype = opts.filetype,
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
            filetype = opts.filetype,
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
                col = col + width + spacing,
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

local HistoryPopup = Object:extend()

function HistoryPopup:setup(config)
    state:assign(config)
end

function HistoryPopup:new(opts)
    return setmetatable({
        vertical_widget = create_vertical_widget(opts),
        horizontal_widget = create_horizontal_widget(opts),
        layout_type = opts.layout_type,
        history_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/history'),
        selected = 1,
        data = nil,
        err = nil,
    }, HistoryPopup)
end

function HistoryPopup:get_data()
    return self.data
end

function HistoryPopup:get_preview_win_ids()
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

function HistoryPopup:get_win_ids()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    return widget:get_win_ids()
end

function HistoryPopup:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
end

function HistoryPopup:set_loading(value)
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

function HistoryPopup:set_error(value)
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:set_error(value)
    return self
end

function HistoryPopup:is_preview_focused()
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

function HistoryPopup:reposition_cursor(selected)
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:get_views().table:set_cursor(selected + 1, 0)
    return self
end

function HistoryPopup:mount()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:mount(true)
    widget:set_loading(true)
    widget:get_views().table:add_keymap('<enter>', string.format('_change_history(%s)', widget:get_parent_buf()))
    return self
end

function HistoryPopup:unmount()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:unmount()
    return self
end

function HistoryPopup:render()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    local views = widget:get_views()
    local table = views.table
    local err, data = self.err, self.data
    widget:clear()
    if err then
        widget:get_views().table:remove_keymap('<enter>')
        widget:set_error(true)
        return self
    elseif data then
        local logs = data.logs
        local diff_change = data.diff_change
        if self.layout_type == 'horizontal' then
            views.preview:set_cursor(1, 0):set_lines(diff_change.lines)
            views.preview:focus()
            painter.draw_changes(function()
                return views.preview:get_buf()
            end, diff_change.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        else
            views.previous:set_cursor(1, 0):set_lines(diff_change.previous_lines)
            views.current:set_cursor(1, 0):set_lines(diff_change.current_lines)
            painter.draw_changes(function(datum)
                local view = views[datum.buftype]
                view:focus()
                return view:get_buf()
            end, diff_change.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        end
        local rows = {}
        for i = 1, #logs do
            local log = logs[i]
            rows[#rows + 1] = {
                string.format('HEAD~%s', i - 1),
                log.author_name or '',
                log.commit_hash or '',
                log.summary or '',
                (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp))) or '',
            }
        end
        table:create_table({ 'Revision', 'Author Name', 'Commit Hash', 'Summary', 'Time' }, rows)
        table:add_indicator(self.selected, self.history_namespace, state:get('indicator').hl)
    else
        table:set_centered_text(t('history/no_commits'))
        table:remove_keymap('<enter>')
    end
    table:focus()
    return self
end

return HistoryPopup
