local utils = require('vgit.utils')
local Interface = require('vgit.Interface')
local Popup = require('vgit.Popup')
local Preview = require('vgit.Preview')

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

local BlamePreview = Preview:extend()

function BlamePreview:setup(config)
    state:assign(config)
end

function BlamePreview:new()
    local this = Preview:new({
        Popup:new({
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
        temporary = true,
    })
    return setmetatable(this, BlamePreview)
end

function BlamePreview:render()
    local err, blame = self.err, self.data
    self:clear()
    if err then
        self:set_error(true)
        return self
    end
    if blame then
        local popup = self:get_popups()[1]
        if not blame.committed then
            local uncommitted_lines = create_uncommitted_lines(blame)
            popup:set_lines(uncommitted_lines)
            popup:set_height(#uncommitted_lines)
            return self
        end
        local committed_lines = create_committed_lines(blame)
        popup:set_lines(committed_lines)
        popup:set_height(#committed_lines)
    end
    return self
end

return BlamePreview
