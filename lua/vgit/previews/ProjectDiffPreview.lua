local dimensions = require('vgit.dimensions')
local TableBuilder = require('vgit.builders.TableBuilder')
local render_settings = require('vgit.render_settings')
local localization = require('vgit.localization')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')
local t = localization.translate

local function create_horizontal_widget(opts)
    local height = math.floor(dimensions.global_height() - 3)
    local table_width = math.floor(dimensions.global_width() * 0.20)
    local preview_width = math.floor(dimensions.global_width() - table_width) - 5
    local spacing = 2
    local row = math.floor((dimensions.global_height() - height) / 2)
    return Preview:new({
        preview = Popup:new({
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
                width = preview_width,
                height = height,
                row = row,
                col = spacing + table_width + 2,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
            title = 'Files Changed',
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
                width = table_width,
                height = height,
                row = row,
                col = spacing,
            },
            static = true,
        }),
    }, opts)
end

local function create_vertical_widget(opts)
    local height = math.floor(dimensions.global_height() - 3)
    local table_width = math.floor(dimensions.global_width() * 0.20)
    local preview_width = math.floor((dimensions.global_width() - table_width) / 2) - 5
    local spacing = 2
    local row = math.floor((dimensions.global_height() - height) / 2)
    return Preview:new({
        previous = Popup:new({
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            border_focus_hl = render_settings.get('preview').border_focus_hl,
            title = 'Previous',
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
                width = preview_width,
                height = height,
                row = row,
                col = spacing + table_width + spacing,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        current = Popup:new({
            title = 'Current',
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
                width = preview_width,
                height = height,
                row = row,
                col = spacing + table_width + spacing + preview_width + spacing,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
        table = Popup:new({
            title = 'Files Changed',
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
                width = table_width,
                height = height,
                row = row,
                col = spacing,
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

function ProjectDiffPreview:get_preview_win_ids()
    if self.layout_type == 'vertical' then
        return {
            self:get_popups().previous:get_win_id(),
            self:get_popups().current:get_win_id(),
        }
    end
    return { self:get_popups().preview:get_win_id() }
end

function ProjectDiffPreview:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
end

function ProjectDiffPreview:is_preview_focused()
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

function ProjectDiffPreview:reposition_cursor(selected)
    local table = self:get_popups().table
    table:set_cursor(selected + 1, 0)
    table:focus()
    return self
end

function ProjectDiffPreview:mount()
    if self.state.mounted then
        return self
    end
    Preview.mount(self)
    self:get_popups().table:add_keymap('<enter>', string.format('_rerender_project_diff(%s)', self:get_parent_buf()))
    return self
end

function ProjectDiffPreview:render()
    local popups = self:get_popups()
    local table = popups.table
    local err, data = self.err, self.data
    self:clear()
    if err then
        if err[1] == 'File not found' then
            local changed_files = data.changed_files
            local warning_text = t('diff/file_not_found')
            if self.layout_type == 'horizontal' then
                popups.preview:set_cursor(1, 0):set_centered_text(warning_text)
            else
                popups.previous:set_cursor(1, 0):set_centered_text(warning_text)
                popups.current:set_cursor(1, 0):set_centered_text(warning_text)
            end
            local rows = {}
            for i = 1, #changed_files do
                local file = changed_files[i]
                rows[#rows + 1] = { string.format('%s %s', file.status, file.filename) }
            end
            local table_builder = TableBuilder:new({ 'Changes' }, rows)
            table_builder:make(table)
            table:transpose_text(
                { render_settings.get('preview').symbols.indicator, render_settings.get('preview').indicator_hl },
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
            { render_settings.get('preview').symbols.indicator, render_settings.get('preview').indicator_hl },
            self.selected,
            0
        )
        self:draw_changes(diff_change)
        self:make_virtual_line_nr(diff_change)
        self:reposition_cursor(self.selected)
    else
        table:set_centered_text(t('diff/no_changes'))
        table:remove_keymap('<enter>')
    end
    table:focus()
    return self
end

return ProjectDiffPreview
