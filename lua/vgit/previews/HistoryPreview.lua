local TableBuilder = require('vgit.builders.TableBuilder')
local render_store = require('vgit.stores.render_store')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')

local config = render_store.get('layout').history_preview

local function create_horizontal_widget(opts)
    return Preview:new({
        preview = Popup:new({
            filetype = opts.filetype,
            border = config.horizontal.preview.border,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.horizontal.preview.background_hl or ''),
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                height = config.horizontal.preview.height,
                width = config.horizontal.preview.width,
                row = config.horizontal.preview.row,
                col = config.horizontal.preview.col,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
            static = true,
            title = 'History',
            border = config.horizontal.table.border,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.horizontal.table.background_hl or ''),
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                height = config.horizontal.table.height,
                width = config.horizontal.table.width,
                row = config.horizontal.table.row,
                col = config.horizontal.table.col,
            },
        }),
    }, opts)
end

local function create_vertical_widget(opts)
    return Preview:new({
        previous = Popup:new({
            filetype = opts.filetype,
            border = config.vertical.previous.border,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.vertical.previous.background_hl or ''),
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = config.vertical.previous.width,
                height = config.vertical.previous.height,
                row = config.vertical.previous.row,
                col = config.vertical.previous.col,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        current = Popup:new({
            filetype = opts.filetype,
            border = config.vertical.current.border,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.vertical.current.background_hl or ''),
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = config.vertical.current.width,
                height = config.vertical.current.height,
                row = config.vertical.current.row,
                col = config.vertical.current.col,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
            static = true,
            border = config.vertical.table.border,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.vertical.table.background_hl or ''),
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = config.vertical.table.width,
                height = config.vertical.table.height,
                row = config.vertical.table.row,
                col = config.vertical.table.col,
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

function HistoryPreview:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
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
    local table = self:get_popups().table
    table:add_keymap('<enter>', string.format('_rerender_history(%s)', self:get_parent_buf()))
    table:focus()
    return self
end

function HistoryPreview:render()
    if not self:is_mounted() then
        return
    end
    local popups = self:get_popups()
    local table = popups.table
    local err, data = self.err, self.data
    self:clear()
    if err then
        self:get_popups().table:remove_keymap('<enter>')
        self:set_error(true)
        table:focus()
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
        if not table:has_lines() then
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
            local table_builder = TableBuilder:new(
                { 'Revision', 'Author Name', 'Commit Hash', 'Summary', 'Time' },
                rows
            )
            table_builder:make(table)
        end
        table:transpose_text(
            { render_store.get('preview').symbols.indicator, render_store.get('preview').indicator_hl },
            self.selected,
            0
        )
        self:draw_changes(diff_change)
        self:make_virtual_line_nr(diff_change)
        self:reposition_cursor(self.selected)
    else
        table:set_centered_text('There are no commits')
        table:remove_keymap('<enter>')
    end
    table:focus()
    return self
end

return HistoryPreview
