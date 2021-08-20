local utils = require('vgit.utils')
local Object = require('plenary.class')
local dimensions = require('vgit.dimensions')
local Interface = require('vgit.Interface')
local View = require('vgit.View')
local Widget = require('vgit.Widget')

local state = Interface:new({
    blame_window = {
        border = { '╭', '─', '─', '│', '─', '─', '╰', '│' },
        border_hl = 'VGitBorder',
    },
    preview_window = {
        border = { '─', '─', '╮', '│', '╯', '─', '─', ' ' },
        border_hl = 'VGitBorder',
    },
})

local BlamePreviewPopup = Object:extend()

function BlamePreviewPopup:setup(config)
    state:assign(config)
end

function BlamePreviewPopup:new(opts)
    local height = dimensions.global_height()
    local blame_width = math.ceil(dimensions.global_width() * 0.40)
    local preview_width = math.ceil(dimensions.global_width() * 0.60)
    return setmetatable({
        widget = Widget:new({
            blame = View:new({
                border = state:get('blame_window').border,
                border_hl = state:get('blame_window').border_hl,
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
            preview = View:new({
                border = state:get('preview_window').border,
                border_hl = state:get('preview_window').border_hl,
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
            popup = true,
        }),
        data = {
            lines = {},
        },
        err = nil,
    }, BlamePreviewPopup)
end

function BlamePreviewPopup:get_data()
    return self.data
end

function BlamePreviewPopup:get_preview_win_ids()
    return { self.widget:get_views().preview:get_win_id() }
end

function BlamePreviewPopup:get_preview_buf()
    return { self.widget:get_views().preview:get_buf() }
end

function BlamePreviewPopup:get_win_ids()
    return self.widget:get_win_ids()
end

function BlamePreviewPopup:set_loading(value)
    self.widget:set_loading(value)
    return self
end

function BlamePreviewPopup:set_error(value)
    self.widget:set_error(value)
    return self
end

function BlamePreviewPopup:set_cursor(row, col)
    self.widget:get_views().preview:set_cursor(row, col)
    return self
end

function BlamePreviewPopup:is_preview_focused()
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

function BlamePreviewPopup:mount()
    self.widget:mount(true)
    return self
end

function BlamePreviewPopup:unmount()
    self.widget:unmount()
    return self
end

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

function BlamePreviewPopup:render()
    local err, data = self.err, self.data
    local views = self.widget:get_views()
    local v = views.preview
    local vb = views.blame
    v:focus()
    if err then
        self.widget:set_error(true)
        return self
    end
    if data then
        v:set_lines(data.lines)
        vb:set_lines(get_blame_lines(data.blames))
    end
    return self
end

return BlamePreviewPopup
