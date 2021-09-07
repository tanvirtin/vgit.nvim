local utils = require('vgit.utils')
local render_store = require('vgit.stores.render_store')
local dimensions = require('vgit.dimensions')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')

local function get_blame_line(blame)
    local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
    local time_format = string.format('%s days ago', utils.round(time))
    local time_divisions = { { 24, 'hours' }, { 60, 'minutes' }, { 60, 'seconds' } }
    local division_counter = 1
    while time < 1 and division_counter ~= #time_divisions do
        local division = time_divisions[division_counter]
        time = time * division[1]
        time_format = string.format('%s %s ago', utils.round(time), division[2])
        division_counter = division_counter + 1
    end
    if blame.committed then
        return string.format(
            '%s (%s) • %s',
            blame.author,
            time_format,
            blame.committed and blame.commit_message or 'Uncommitted changes'
        )
    end
    return 'Uncommitted changes'
end

local function get_blame_lines(blames)
    local blame_lines = {}
    local last_blame = nil
    for i = 1, #blames do
        local blame = blames[i]
        if last_blame then
            if blame.commit_hash == last_blame.commit_hash then
                blame_lines[#blame_lines + 1] = ''
            else
                blame_lines[#blame_lines + 1] = get_blame_line(blame)
            end
        else
            blame_lines[#blame_lines + 1] = get_blame_line(blame)
        end
        last_blame = blame
    end
    return blame_lines
end

local GutterBlamePreview = Preview:extend()

function GutterBlamePreview:new(opts)
    local height = dimensions.global_height()
    local blame_width = math.floor(dimensions.global_width() * 0.40)
    local preview_width = math.floor(dimensions.global_width() * 0.60)
    local this = Preview:new({
        blame = Popup:new({
            border = render_store.get('preview').border,
            border_hl = render_store.get('preview').border_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'cursor',
                height = height,
                width = blame_width,
                focusable = false,
                row = 0,
                col = 0,
            },
        }),
        preview = Popup:new({
            border = render_store.get('preview').border,
            border_hl = render_store.get('preview').border_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
                ['number'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'cursor',
                height = height,
                width = preview_width,
                row = 0,
                col = blame_width,
            },
            filetype = opts.filetype,
        }),
    }, {
        temporary = true,
    })
    return setmetatable(this, GutterBlamePreview)
end

function GutterBlamePreview:get_preview_win_ids()
    return { self:get_popups().preview:get_win_id() }
end

function GutterBlamePreview:get_preview_buf()
    return { self:get_popups().preview:get_buf() }
end

function GutterBlamePreview:set_cursor(row, col)
    self:get_popups().preview:set_cursor(row, col)
    return self
end

function GutterBlamePreview:is_preview_focused()
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

function GutterBlamePreview:render()
    local err, data = self.err, self.data
    self:clear()
    local popups = self:get_popups()
    if err then
        self:set_error(true)
        return self
    end
    if data then
        popups.preview:set_lines(data.lines)
        popups.blame:set_lines(get_blame_lines(data.blames))
    end
    popups.preview:focus()
    return self
end

return GutterBlamePreview
