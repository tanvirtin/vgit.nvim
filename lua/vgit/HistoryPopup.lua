local paint = require('vgit.paint')
local virtual_text = require('vgit.virtual_text')
local dimensions = require('vgit.dimensions')
local Interface = require('vgit.Interface')
local localization = require('vgit.localization')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local sign = require('vgit.sign')
local t = localization.translate

local vim = vim

local HistoryPopup = {}
HistoryPopup.__index = HistoryPopup

local state = Interface.new({
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
    history_window = {
        title = t('history/history'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
})

local function setup(config)
    state:assign(config)
end

local function colorize_indicator(buf, lnum, namespace)
    virtual_text.transpose_text(buf, '>', namespace, state:get('indicator').hl, lnum, 0)
end

local function create_history_lines(logs)
    local padding_right = 2
    local table_title_space = { padding_right, padding_right, padding_right, padding_right, 0 }
    local rows = {}
    for i = 1, #logs do
        local log = logs[i]
        local row = {
            string.format('   HEAD~%s', i - 1),
            log.author_name or '',
            log.commit_hash or '',
            log.summary or '',
            (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp))) or '',
        }
        for j = 1, #row do
            local item = row[j]
            if #item + 1 > table_title_space[j] then
                table_title_space[j] = #item + padding_right
            end
        end
        rows[#rows + 1] = row
    end
    local history_lines = {}
    for i = 1, #rows do
        local row = rows[i]
        local line = ''
        for j = 1, #row do
            local item = row[j]
            line = line .. item .. string.rep(' ', table_title_space[j] - #item)
            if j ~= #table_title_space then
                line = line
            end
        end
        history_lines[#history_lines + 1] = line
    end
    return history_lines
end

local function create_horizontal_widget(opts)
    local height = math.ceil(dimensions.global_height() - 13)
    local width = math.ceil(dimensions.global_width() * 0.8)
    local col = math.ceil((dimensions.global_width() - width) / 2) - 1
    local views = {
        preview = View.new({
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
        history = View.new({
            title = state:get('history_window').title,
            border = state:get('history_window').border,
            border_hl = state:get('history_window').border_hl,
            border_focus_hl = state:get('history_window').border_focus_hl,
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
    return Widget.new(views, { name = 'horizontal_history' })
end

local function create_vertical_widget(opts)
    local height = math.ceil(dimensions.global_height() - 13)
    local width = math.ceil(dimensions.global_width() * 0.485)
    local col = math.ceil((dimensions.global_width() - (width * 2)) / 2) - 1
    local views = {
        previous = View.new({
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
        current = View.new({
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
                col = col + width + 2,
            },
        }),
        history = View.new({
            title = state:get('history_window').title,
            border = state:get('history_window').border,
            border_hl = state:get('history_window').border_hl,
            border_focus_hl = state:get('history_window').border_focus_hl,
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
    return Widget.new(views, { name = 'vertical_history' })
end

local function new(opts)
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

function HistoryPopup:get_name()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    return widget:get_name()
end

function HistoryPopup:get_win_ids()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    return widget:get_win_ids()
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

function HistoryPopup:mount()
    local widget = self.horizontal_widget
    if self.layout_type == 'vertical' then
        widget = self.vertical_widget
    end
    widget:mount(true)
    widget:set_loading(true)
    widget:get_views().history:focus()
    widget:get_views().history:add_keymap('<enter>', string.format('_change_history(%s)', widget:get_parent_buf()))
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
    local err, data = self.err, self.data
    if err then
        widget:set_error(true)
        return self
    end
    if data then
        local views = widget:get_views()
        if err then
            local no_commits_str = 'does not have any commits yet'
            if
                type(err) == 'table'
                and #err > 0
                and type(err[1]) == 'string'
                and err[1]:sub(#err[1] - #no_commits_str + 1, #err[1]) == no_commits_str
            then
                widget:set_centered_text(t('history/no_commits'))
                return self
            end
            widget:set_error(true)
            return self
        end
        if self.layout_type == 'horizontal' then
            views.preview:set_cursor(1, 0)
            views.preview:set_lines(data.lines)
            sign.unplace(views.preview:get_buf())
            paint.changes(function()
                return views.preview:get_buf()
            end, data.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        else
            views.previous:set_cursor(1, 0)
            views.current:set_cursor(1, 0)
            views.previous:set_lines(data.previous_lines)
            views.current:set_lines(data.current_lines)
            sign.unplace(views.previous:get_buf())
            sign.unplace(views.current:get_buf())
            paint.changes(function(datum)
                return views[datum.buftype]:get_buf()
            end, data.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        end
        views.history:set_lines(create_history_lines(data.logs))
        colorize_indicator(views.history:get_buf(), self.selected - 1, self.history_namespace)
    end
    return self
end

return {
    new = new,
    setup = setup,
}
