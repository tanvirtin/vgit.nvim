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

local function create_horizontal_widget(opts)
    local height = math.floor(dimensions.global_height() - 3)
    local table_width = math.floor(dimensions.global_width() * 0.20)
    local preview_width = math.floor(dimensions.global_width() - table_width) - 5
    local spacing = 2
    local row = math.floor((dimensions.global_height() - height) / 2)
    return Preview:new({
        preview = Popup:new({
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
                col = spacing + table_width + 2,
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
                width = table_width,
                height = height,
                row = row,
                col = spacing,
            },
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
                width = preview_width,
                height = height,
                row = row,
                col = spacing + table_width + spacing,
            },
        }),
        current = Popup:new({
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
                width = preview_width,
                height = height,
                row = row,
                col = spacing + table_width + spacing + preview_width + spacing,
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
                width = table_width,
                height = height,
                row = row,
                col = spacing,
            },
        }),
    }, opts)
end

local ProjectDiffPreview = Preview:extend()

function ProjectDiffPreview:setup(config)
    state:assign(config)
end

function ProjectDiffPreview:new(opts)
    local this = create_vertical_widget(opts)
    if opts.layout_type == 'horizontal' then
        this = create_horizontal_widget(opts)
    end
    this.selected = 1
    this.diff_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/diff')
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
            table:make_table({ 'Filename' }, rows)
            table:add_indicator(self.selected, self.diff_namespace, state:get('indicator').hl)
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
            popups.preview:focus()
            painter.draw_changes(function()
                return popups.preview:get_buf()
            end, diff_change.lnum_changes, state:get(
                'signs'
            ), state:get(
                'priority'
            ))
        else
            popups.previous:set_cursor(1, 0):set_lines(diff_change.previous_lines):set_filetype(filetype)
            popups.current:set_cursor(1, 0):set_lines(diff_change.current_lines):set_filetype(filetype)
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
        for i = 1, #changed_files do
            local file = changed_files[i]
            rows[#rows + 1] = { string.format('%s %s', file.status, file.filename) }
        end
        table:make_table({ 'Filename' }, rows)
        table:add_indicator(self.selected, self.diff_namespace, state:get('indicator').hl)
        self:reposition_cursor(self.selected)
    else
        table:set_centered_text(t('diff/no_changes'))
        table:remove_keymap('<enter>')
    end
    table:focus()
    return self
end

return ProjectDiffPreview
