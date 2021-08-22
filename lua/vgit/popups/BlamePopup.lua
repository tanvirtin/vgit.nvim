local utils = require('vgit.utils')
local Object = require('plenary.class')
local Interface = require('vgit.Interface')
local View = require('vgit.View')
local Widget = require('vgit.Widget')

local state = Interface:new({
    window = {
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
    },
})

local function create_uncommitted_lines(blame)
    return {
        string.format('%sLine #%s', '  ', blame.lnum),
        string.format('%s%s', '  ', 'Uncommitted changes'),
        string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
    }
end

local function create_committed_lines(blame)
    local max_line_length = 88
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
    local commit_message = blame.commit_message
    if #commit_message > max_line_length then
        commit_message = commit_message:sub(1, max_line_length) .. '...'
    end
    return {
        string.format('%sLine #%s', '  ', blame.lnum),
        string.format('  %s (%s)', blame.author, blame.author_mail),
        string.format('  %s (%s)', time_format, os.date('%c', blame.author_time)),
        string.format('%s%s', '  ', commit_message),
        string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
    }
end

local BlamePopup = Object:extend()

function BlamePopup:setup(config)
    state:assign(config)
end

function BlamePopup:new()
    return setmetatable({
        widget = Widget:new({
            View:new({
                border = state:get('window').border,
                border_hl = state:get('window').border_hl,
                win_options = { ['cursorline'] = true },
                window_props = {
                    style = 'minimal',
                    relative = 'cursor',
                    height = 5,
                    width = 88,
                    row = 0,
                    col = 0,
                },
            }),
        }, {
            popup = true,
        }),
        data = nil,
        err = nil,
    }, BlamePopup)
end

function BlamePopup:get_win_ids()
    return self.widget:get_win_ids()
end

function BlamePopup:set_loading(value)
    self.widget:set_loading(value)
    return self
end

function BlamePopup:set_error(value)
    self.widget:set_error(value)
    return self
end

function BlamePopup:mount()
    self.widget:mount()
    return self
end

function BlamePopup:unmount()
    self.widget:unmount()
    return self
end

function BlamePopup:render()
    local widget = self.widget
    local err, blame = self.err, self.data
    widget:clear()
    if err then
        widget:set_error(true)
        return self
    end
    if blame then
        local view = widget:get_views()[1]
        if not blame.committed then
            local uncommitted_lines = create_uncommitted_lines(blame)
            view:set_lines(uncommitted_lines)
            view:set_height(#uncommitted_lines)
            return self
        end
        local committed_lines = create_committed_lines(blame)
        view:set_lines(committed_lines)
        view:set_height(#committed_lines)
    end
    return self
end

return BlamePopup
