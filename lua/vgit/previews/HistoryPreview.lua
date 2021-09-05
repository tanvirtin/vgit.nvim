local dimensions = require('vgit.dimensions')
local render_settings = require('vgit.render_settings')
local localization = require('vgit.localization')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')
local t = localization.translate

local function create_horizontal_widget(opts)
    local height = math.floor(dimensions.global_height() - 13)
    local width = math.floor(dimensions.global_width() * 0.9)
    local col = math.ceil((dimensions.global_width() - width) / 2)
    return Preview:new({
        preview = Popup:new({
            filetype = opts.filetype,
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            border_focus_hl = render_settings.get('preview').border_focus_hl,
            title = 'Preview',
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
            title = 'History',
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            border_focus_hl = render_settings.get('preview').border_focus_hl,
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
            title = 'Previous',
            filetype = opts.filetype,
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            border_focus_hl = render_settings.get('preview').border_focus_hl,
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
            title = 'Current',
            filetype = opts.filetype,
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            border_focus_hl = render_settings.get('preview').border_focus_hl,
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
            title = 'History',
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            border_focus_hl = render_settings.get('preview').border_focus_hl,
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

function HistoryPreview:new(opts)
    local this = create_vertical_widget(opts)
    if opts.layout_type == 'horizontal' then
        this = create_horizontal_widget(opts)
    end
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
        else
            popups.previous:set_cursor(1, 0):set_lines(diff_change.previous_lines)
            popups.current:set_cursor(1, 0):set_lines(diff_change.current_lines)
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
        table:add_indicator(self.selected)
        self:draw_changes(diff_change)
        self:make_virtual_line_nr(diff_change)
        self:reposition_cursor(self.selected)
    else
        table:set_centered_text(t('history/no_commits'))
        table:remove_keymap('<enter>')
    end
    table:focus()
    return self
end

return HistoryPreview
