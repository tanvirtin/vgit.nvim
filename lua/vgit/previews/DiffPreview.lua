local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')
local render_store = require('vgit.stores.render_store')

local config = render_store.get('layout').diff_preview

local DiffPreview = Preview:extend()

local function create_horizontal_widget(opts)
    return Preview:new({
        preview = Popup:new({
            filetype = opts.filetype,
            border = config.horizontal.border,
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.horizontal.background_hl or ''),
                ['cursorline'] = true,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = config.horizontal.width,
                height = config.horizontal.height,
                row = config.horizontal.row,
                col = config.horizontal.col,
            },
            virtual_line_nr = {
                enabled = true,
            },
        }),
    }, opts)
end

local function create_vertical_widget(opts)
    return Preview:new({
        previous = Popup:new({
            filetype = opts.filetype,
            border = config.vertical.previous.border,
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.vertical.previous.background_hl or ''),
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
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
            win_options = {
                ['winhl'] = string.format('Normal:%s', config.vertical.previous.background_hl or ''),
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
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
    }, opts)
end

function DiffPreview:new(opts)
    local this = create_vertical_widget(opts)
    if opts.layout_type == 'horizontal' then
        this = create_horizontal_widget(opts)
    end
    return setmetatable(this, DiffPreview)
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
    if not self:is_mounted() then
        return
    end
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
