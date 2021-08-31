local painter = require('vgit.painter')
local dimensions = require('vgit.dimensions')
local Interface = require('vgit.Interface')
local localization = require('vgit.localization')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')
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
    return Preview:new({
        preview = Popup:new({
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
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
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
    }, opts)
end

local function create_vertical_widget(opts)
    local height = math.floor(dimensions.global_height() - 13)
    local width = math.floor((dimensions.global_width()) / 2) - 5
    local col = math.ceil((dimensions.global_width() - (width * 2)) / 2)
    local spacing = 2
    return Preview:new({
        previous = Popup:new({
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
            virtual_line_nr = {
                enabled = true,
            },
        }),
        current = Popup:new({
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
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
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
    }, opts)
end

local HistoryPreview = Preview:extend()

function HistoryPreview:setup(config)
    state:assign(config)
end

function HistoryPreview:new(opts)
    local this = create_vertical_widget(opts)
    if opts.layout_type == 'horizontal' then
        this = create_horizontal_widget(opts)
    end
    this.selected = 1
    this.history_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/history')
    return setmetatable(this, HistoryPreview)
end

function HistoryPreview:get_preview_win_ids()
    if self.layout_type == 'vertical' then
        return {
            self:get_popups().previous:get_win_id(),
            self:get_popups().current:get_win_id(),
        }
    end
    return { self:get_popups().preview:get_win_id() }
end

function HistoryPreview:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
end

function HistoryPreview:is_preview_focused()
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

function HistoryPreview:reposition_cursor(selected)
    self:get_popups().table:set_cursor(selected + 1, 0)
    return self
end

function HistoryPreview:mount()
    if self.state.mounted then
        return self
    end
    Preview.mount(self)
    self:get_popups().table:add_keymap('<enter>', string.format('_rerender_history(%s)', self:get_parent_buf()))
    return self
end

function HistoryPreview:render()
    local popups = self:get_popups()
    local table = popups.table
    local err, data = self.err, self.data
    self:clear()
    if err then
        self:get_popups().table:remove_keymap('<enter>')
        self:set_error(true)
        return self
    elseif data then
        local logs = data.logs
        local diff_change = data.diff_change
        if self.layout_type == 'horizontal' then
            popups.preview:set_cursor(1, 0):set_lines(diff_change.lines)
            popups.preview:focus()
            painter.draw_changes(function()
                return popups.preview:get_buf()
            end, diff_change.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        else
            popups.previous:set_cursor(1, 0):set_lines(diff_change.previous_lines)
            popups.current:set_cursor(1, 0):set_lines(diff_change.current_lines)
            painter.draw_changes(function(datum)
                local popup = popups[datum.buftype]
                popup:focus()
                return popup:get_buf()
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
        table:make_table({ 'Revision', 'Author Name', 'Commit Hash', 'Summary', 'Time' }, rows)
        table:add_indicator(self.selected, self.history_namespace, state:get('indicator').hl)
        self:make_virtual_line_nr(diff_change, self.layout_type)
        self:reposition_cursor(self.selected)
    else
        table:set_centered_text(t('history/no_commits'))
        table:remove_keymap('<enter>')
    end
    table:focus()
    return self
end

return HistoryPreview
