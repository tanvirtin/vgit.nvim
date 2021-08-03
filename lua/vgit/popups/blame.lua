local State = require('vgit.State')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local a = require('plenary.async')
local wrap = a.wrap
local scheduler = a.util.scheduler

local function round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

local M = {}

M.constants = {
    max_line_length = 88,
}

M.state = State.new({
    window = {
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
    },
})

M.setup = function(config)
    M.state:assign(config)
end

local function create_uncommitted_lines(blame)
    return {
        string.format('%sLine #%s', '  ', blame.lnum),
        string.format('%s%s', '  ', 'Uncommitted changes'),
        string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
    }
end

local function create_committed_lines(blame)
    local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
    local time_format = string.format('%s days ago', round(time))
    local time_divisions = { { 24, 'hours' }, { 60, 'minutes' }, { 60, 'seconds' } }
    local division_counter = 1
    while time < 1 and division_counter ~= #time_divisions do
        local division = time_divisions[division_counter]
        time = time * division[1]
        time_format = string.format('%s %s ago', round(time), division[2])
        division_counter = division_counter + 1
    end
    local commit_message = blame.commit_message
    if #commit_message > M.constants.max_line_length then
        commit_message = commit_message:sub(1, M.constants.max_line_length) .. '...'
    end
    return {
        string.format('%sLine #%s', '  ', blame.lnum),
        string.format('  %s (%s)', blame.author, blame.author_mail),
        string.format('  %s (%s)', time_format, os.date('%c', blame.author_time)),
        string.format('%s%s', '  ', commit_message),
        string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
    }
end

local function create_widget()
    local view = View.new({
        border = M.state:get('window').border,
        border_hl = M.state:get('window').border_hl,
        win_options = { ['cursorline'] = true },
        window_props = {
            style = 'minimal',
            relative = 'cursor',
            height = 5,
            width = M.constants.max_line_length,
            row = 0,
            col = 0,
        },
    })
    return Widget.new({ view }, 'blame')
end

M.show = wrap(function(fetch)
    scheduler()
    local widget = create_widget()
    widget:render(true):set_loading(true)
    scheduler()
    local err, blame = fetch()
    scheduler()
    widget:set_loading(false)
    scheduler()
    if err then
        widget:set_error(true)
        return widget
    end
    local view = widget:get_views()[1]
    if not blame.committed then
        local uncommitted_lines = create_uncommitted_lines(blame)
        view:set_lines(uncommitted_lines)
        view:set_height(#uncommitted_lines)
        return widget
    end
    local committed_lines = create_committed_lines(blame)
    view:set_lines(committed_lines)
    view:set_height(#committed_lines)
    return widget
end, 1)

return M
