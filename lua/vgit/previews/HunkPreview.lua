local dimensions = require('vgit.dimensions')
local render_settings = require('vgit.render_settings')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')

local HunkPreview = Preview:extend()

function HunkPreview:new(opts)
    local this = Preview:new({
        preview = Popup:new({
            border = render_settings.get('preview').border,
            border_hl = render_settings.get('preview').border_hl,
            win_options = { ['cursorline'] = true },
            window_props = {
                style = 'minimal',
                relative = 'cursor',
                width = dimensions.global_width(),
                row = 0,
                col = 0,
            },
            filetype = opts.filetype,
        }),
    }, {
        temporary = true,
        layout_type = 'horizontal',
        selected = 1,
    })
    return setmetatable(this, HunkPreview)
end

function HunkPreview:get_preview_win_ids()
    return { self:get_popups().preview:get_win_id() }
end

function HunkPreview:get_marks()
    return self.data and self.data.diff_change and self.data.diff_change.marks or {}
end

function HunkPreview:set_cursor(row, col)
    self:get_popups().preview:set_cursor(row, col)
    return self
end

function HunkPreview:is_preview_focused()
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

function HunkPreview:reposition_cursor(lnum)
    local new_lines_added = 0
    local hunks = self.data.diff_change.hunks
    for i = 1, #hunks do
        local hunk = hunks[i]
        local type = hunk.type
        local diff = hunk.diff
        local current_new_lines_added = 0
        if type == 'remove' then
            for _ = 1, #diff do
                current_new_lines_added = current_new_lines_added + 1
            end
        elseif type == 'change' then
            for j = 1, #diff do
                local line = diff[j]
                local line_type = line:sub(1, 1)
                if line_type == '-' then
                    current_new_lines_added = current_new_lines_added + 1
                end
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
            vim.cmd('norm! zt')
            break
        end
    end
end

function HunkPreview:render()
    local err, data = self.err, self.data
    self:clear()
    if err then
        self:set_error(true)
        return self
    end
    if data then
        local diff_change = data.diff_change
        local popups = self:get_popups()
        local popup = popups.preview
        popup:set_lines(diff_change.lines)
        local new_width = #data.selected_hunk.diff
        if new_width ~= 0 then
            if new_width > popup:get_min_height() then
                popup:set_height(new_width)
            else
                popup:set_height(popup:get_min_height())
            end
        end
        self:draw_changes(diff_change)
        self:reposition_cursor(self.selected)
    end
    return self
end

return HunkPreview
