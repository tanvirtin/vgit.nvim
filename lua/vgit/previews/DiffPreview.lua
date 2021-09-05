local dimensions = require('vgit.dimensions')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')
local render_settings = require('vgit.render_settings')

local DiffPreview = Preview:extend()

local function create_horizontal_widget(opts)
    local height = math.floor(dimensions.global_height() - 4)
    local width = math.floor(dimensions.global_width() * 0.85)
    local col = math.floor((dimensions.global_width() - width) / 2) - 1
    return Preview:new({
        preview = Popup:new({
            title = 'Preview',
            filetype = opts.filetype,
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            border_focus_hl = render_settings.get('preview').border_focus_hl,
            win_options = {
                ['cursorline'] = true,
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
    }, opts)
end

local function create_vertical_widget(opts)
    local height = math.floor(dimensions.global_height() - 4)
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
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
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
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
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
    }, opts)
end

function DiffPreview:new(opts)
    local this = create_vertical_widget(opts)
    if opts.layout_type == 'horizontal' then
        this = create_horizontal_widget(opts)
    end
    return setmetatable(this, DiffPreview)
end

function DiffPreview:get_preview_win_ids()
    if self.layout_type == 'vertical' then
        return {
            self:get_popups().previous:get_win_id(),
            self:get_popups().current:get_win_id(),
        }
    end
    return { self:get_popups().preview:get_win_id() }
end

function DiffPreview:get_marks()
    return self.data and self.data.marks or {}
end

function DiffPreview:is_preview_focused()
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

function DiffPreview:set_cursor(row, col)
    if self.layout_type == 'vertical' then
        self:get_popups().previous:set_cursor(row, col)
        self:get_popups().current:set_cursor(row, col)
    else
        self:get_popups().preview:set_cursor(row, col)
    end
    return self
end

function DiffPreview:reposition_cursor(lnum)
    local new_lines_added = 0
    for i = 1, #self.data.hunks do
        local hunk = self.data.hunks[i]
        local type = hunk.type
        local diff = hunk.diff
        local current_new_lines_added = 0
        if type == 'remove' then
            for _ = 1, #diff do
                current_new_lines_added = current_new_lines_added + 1
            end
        elseif type == 'change' then
            local removed_lines, added_lines = hunk:parse_diff()
            if self.layout_type == 'vertical' then
                if #removed_lines ~= #added_lines and #removed_lines > #added_lines then
                    current_new_lines_added = current_new_lines_added + (#removed_lines - #added_lines)
                end
            else
                current_new_lines_added = current_new_lines_added + #removed_lines
            end
        end
        new_lines_added = new_lines_added + current_new_lines_added
        local start = hunk.start + new_lines_added
        local finish = hunk.finish + new_lines_added
        local padded_lnum = lnum + new_lines_added
        if padded_lnum >= start and padded_lnum <= finish then
            if type == 'remove' then
                self:set_cursor(start - current_new_lines_added + 1, 0)
            else
                self:set_cursor(start - current_new_lines_added, 0)
            end
            vim.cmd('norm! zz')
            break
        end
    end
end

function DiffPreview:render()
    local err, diff_change = self.err, self.data
    self:clear()
    if err then
        self:set_error(true)
        return self
    end
    if diff_change then
        if self.layout_type == 'horizontal' then
            local popups = self:get_popups()
            popups.preview:set_lines(diff_change.lines)
            popups.preview:focus()
            popups.preview:focus()
        else
            local popups = self:get_popups()
            popups.previous:set_lines(diff_change.previous_lines)
            popups.current:set_lines(diff_change.current_lines)
        end
        self:draw_changes(diff_change)
        self:make_virtual_line_nr(diff_change)
        self:reposition_cursor(self.selected)
    end
    return self
end

return DiffPreview
