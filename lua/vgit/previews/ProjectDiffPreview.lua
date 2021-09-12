local TableBuilder = require('vgit.builders.TableBuilder')
local render_store = require('vgit.stores.render_store')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')

local config = render_store.get('layout').project_diff_preview

local function create_horizontal_widget(opts)
    return Preview:new({
        preview = Popup:new({
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
                width = config.horizontal.preview.width,
                height = config.horizontal.preview.height,
                row = config.horizontal.preview.row,
                col = config.horizontal.preview.col,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
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
                width = config.horizontal.table.width,
                height = config.horizontal.table.height,
                row = config.horizontal.table.row,
                col = config.horizontal.table.col,
            },
            static = true,
        }),
    }, opts)
end

local function create_vertical_widget(opts)
    return Preview:new({
        previous = Popup:new({
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
                height = config.vertical.previous.height,
                width = config.vertical.previous.width,
                row = config.vertical.previous.row,
                col = config.vertical.previous.col,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        current = Popup:new({
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
                height = config.vertical.current.height,
                width = config.vertical.current.width,
                row = config.vertical.current.row,
                col = config.vertical.current.col,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
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
                height = config.vertical.table.height,
                width = config.vertical.table.width,
                row = config.vertical.table.row,
                col = config.vertical.table.col,
            },
            static = true,
        }),
    }, opts)
end

local ProjectDiffPreview = Preview:extend()

function ProjectDiffPreview:new(opts)
    local this = create_vertical_widget(opts)
    if opts.layout_type == 'horizontal' then
        this = create_horizontal_widget(opts)
    end
    return setmetatable(this, ProjectDiffPreview)
end

function ProjectDiffPreview:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
end

function ProjectDiffPreview:reposition_cursor(selected)
    local table = self:get_popups().table
    table:set_cursor(selected + 1, 0)
    return self
end

function ProjectDiffPreview:mount()
    if self.state.mounted then
        return self
    end
    Preview.mount(self)
    local table = self:get_popups().table
    table:add_keymap('<enter>', string.format('_rerender_project_diff(%s)', self:get_parent_buf()))
    table:focus()
    return self
end

function ProjectDiffPreview:render()
    if not self:is_mounted() then
        return
    end
    local popups = self:get_popups()
    local table = popups.table
    local err, data = self.err, self.data
    self:clear()
    if err then
        if err[1] == 'File not found' then
            local changed_files = data.changed_files
            local file_not_found_msg = 'File has been deleted'
            if self.layout_type == 'horizontal' then
                popups.preview:set_cursor(1, 0):set_centered_text(file_not_found_msg)
            else
                popups.previous:set_cursor(1, 0):set_centered_text(file_not_found_msg)
                popups.current:set_cursor(1, 0):set_centered_text(file_not_found_msg)
            end
            local rows = {}
            for i = 1, #changed_files do
                local file = changed_files[i]
                rows[#rows + 1] = { string.format('%s %s', file.status, file.filename) }
            end
            local table_builder = TableBuilder:new({ 'Changes' }, rows)
            table_builder:make(table)
            table:transpose_text(
                { render_store.get('preview').symbols.indicator, render_store.get('preview').indicator_hl },
                self.selected,
                0
            )
            self:reposition_cursor(self.selected)
            table:focus()
            return
        end
        self:get_popups().table:remove_keymap('<enter>')
        self:set_error(true)
        return self
    elseif data then
        local changed_files = data.changed_files
        local diff_change = data.diff_change
        local filetype = data.filetype
        if self.layout_type == 'horizontal' then
            popups.preview:set_cursor(1, 0):set_lines(diff_change.lines):set_filetype(filetype)
        else
            popups.previous:set_cursor(1, 0):set_lines(diff_change.previous_lines):set_filetype(filetype)
            popups.current:set_cursor(1, 0):set_lines(diff_change.current_lines):set_filetype(filetype)
        end
        if not table:has_lines() then
            local rows = {}
            for i = 1, #changed_files do
                local file = changed_files[i]
                rows[#rows + 1] = { string.format('%s %s', file.status, file.filename) }
            end
            local table_builder = TableBuilder:new({ 'Changes' }, rows)
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
        table:set_centered_text('There are no changes')
        table:remove_keymap('<enter>')
    end
    table:focus()
    return self
end

return ProjectDiffPreview
