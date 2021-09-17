local TableComponent = require('vgit.components.TableComponent')
local utils = require('vgit.utils')
local render_store = require('vgit.stores.render_store')
local CodeComponent = require('vgit.components.CodeComponent')
local Preview = require('vgit.Preview')

local config = render_store.get('layout').project_diff_preview

local function create_horizontal_widget(opts)
    return Preview:new({
        preview = CodeComponent:new({
            border = utils.retrieve(config.horizontal.preview.border),
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', utils.retrieve(config.horizontal.preview.background_hl) or ''),
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = utils.retrieve(config.horizontal.preview.width),
                height = utils.retrieve(config.horizontal.preview.height),
                row = utils.retrieve(config.horizontal.preview.row),
                col = utils.retrieve(config.horizontal.preview.col),
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = TableComponent:new({
            header = { 'Changes' },
            column_spacing = 3,
            max_column_len = 100,
            border = utils.retrieve(config.horizontal.table.border),
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', utils.retrieve(config.horizontal.table.background_hl) or ''),
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = utils.retrieve(config.horizontal.table.width),
                height = utils.retrieve(config.horizontal.table.height),
                row = utils.retrieve(config.horizontal.table.row),
                col = utils.retrieve(config.horizontal.table.col),
            },
            static = true,
        }),
    }, opts)
end

local function create_vertical_widget(opts)
    return Preview:new({
        previous = CodeComponent:new({
            border = utils.retrieve(config.vertical.previous.border),
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', utils.retrieve(config.vertical.previous.background_hl) or ''),
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                height = utils.retrieve(config.vertical.previous.height),
                width = utils.retrieve(config.vertical.previous.width),
                row = utils.retrieve(config.vertical.previous.row),
                col = utils.retrieve(config.vertical.previous.col),
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        current = CodeComponent:new({
            border = utils.retrieve(config.vertical.current.border),
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', utils.retrieve(config.vertical.current.background_hl) or ''),
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                height = utils.retrieve(config.vertical.current.height),
                width = utils.retrieve(config.vertical.current.width),
                row = utils.retrieve(config.vertical.current.row),
                col = utils.retrieve(config.vertical.current.col),
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = TableComponent:new({
            header = { 'Changes' },
            column_spacing = 3,
            max_column_len = 100,
            border = utils.retrieve(config.vertical.table.border),
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', utils.retrieve(config.vertical.table.background_hl) or ''),
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                height = utils.retrieve(config.vertical.table.height),
                width = utils.retrieve(config.vertical.table.width),
                row = utils.retrieve(config.vertical.table.row),
                col = utils.retrieve(config.vertical.table.col),
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

function ProjectDiffPreview:reposition_cursor(selected)
    local table = self:get_components().table
    table:set_cursor(selected + 1, 0)
    return self
end

function ProjectDiffPreview:mount()
    if self.state.mounted then
        return self
    end
    Preview.mount(self)
    local table = self:get_components().table
    table:add_keymap('<enter>', string.format('_rerender_project_diff(%s)', self:get_parent_buf()))
    table:add_keymap('<2-LeftMouse>', string.format('_rerender_project_diff(%s)', self:get_parent_buf()))
    table:focus()
    return self
end

function ProjectDiffPreview:render()
    if not self:is_mounted() then
        return
    end
    local components = self:get_components()
    local table = components.table
    local err, data = self.err, self.data
    self:clear()
    if err then
        if err[1] == 'File not found' then
            local changed_files = data.changed_files
            local file_not_found_msg = 'File has been deleted'
            if self.layout_type == 'horizontal' then
                components.preview:set_cursor(1, 0):set_centered_text(file_not_found_msg)
            else
                components.previous:set_cursor(1, 0):set_centered_text(file_not_found_msg)
                components.current:set_cursor(1, 0):set_centered_text(file_not_found_msg)
            end
            local rows = {}
            for i = 1, #changed_files do
                local file = changed_files[i]
                rows[#rows + 1] = { string.format('%s %s', file.status, file.filename) }
            end
            table:set_lines(rows)
            table:transpose_text(
                { render_store.get('preview').symbols.indicator, render_store.get('preview').indicator_hl },
                self.selected,
                0
            )
            self:reposition_cursor(self.selected)
            table:focus()
            return
        end
        self:set_error(true)
        table:transpose_text(
            { render_store.get('preview').symbols.indicator, render_store.get('preview').indicator_hl },
            self.selected,
            0
        )
        self:reposition_cursor(self.selected)
        return self
    elseif data then
        local changed_files = data.changed_files
        local diff_change = data.diff_change
        local filetype = data.filetype
        if self.layout_type == 'horizontal' then
            components.preview:set_cursor(1, 0):set_lines(diff_change.lines):set_filetype(filetype)
        else
            components.previous:set_cursor(1, 0):set_lines(diff_change.previous_lines):set_filetype(filetype)
            components.current:set_cursor(1, 0):set_lines(diff_change.current_lines):set_filetype(filetype)
        end
        if not table:has_lines() then
            local rows = {}
            for i = 1, #changed_files do
                local file = changed_files[i]
                rows[#rows + 1] = { string.format('%s %s', file.status, file.filename) }
            end
            table:set_lines(rows)
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
        table:remove_keymap('<2-LeftMouse>')
    end
    table:focus()
    return self
end

return ProjectDiffPreview
