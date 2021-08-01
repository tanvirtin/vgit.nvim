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

M.state = State.new({
    window = {
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
    },
})

M.setup = function(config)
    M.state:assign(config)
end

M.render = wrap(function(fetch)
    scheduler()
    local max_commit_message_length = 88
    local view = View.new({
        lines = {},
        border = M.state:get('window').border,
        border_hl = M.state:get('window').border_hl,
        win_options = { ['cursorline'] = true },
        window_props = {
            style = 'minimal',
            relative = 'cursor',
            height = 5,
            width = max_commit_message_length,
            row = 0,
            col = 0,
        },
    })
    local widget = Widget.new({ view }, 'blame'):render(true):set_loading(true)
    scheduler()
    local err, blame = fetch()
    scheduler()
    widget:set_loading(false)
    scheduler()
    if err then
        widget:set_error(true)
        return widget
    else
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
        if not blame.committed then
            commit_message = 'Uncommitted changes'
            local new_lines = {
                string.format('%sLine #%s', '  ', blame.lnum),
                string.format('%s%s', '  ', commit_message),
                string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
            }
            view:set_lines(new_lines)
            view:set_height(#new_lines)
            return widget
        end
        if #commit_message > max_commit_message_length then
            commit_message = commit_message:sub(1, max_commit_message_length) .. '...'
        end
        local new_lines = {
            string.format('%sLine #%s', '  ', blame.lnum),
            string.format('  %s (%s)', blame.author, blame.author_mail),
            string.format('  %s (%s)', time_format, os.date('%c', blame.author_time)),
            string.format('%s%s', '  ', commit_message),
            string.format('%s%s -> %s', '  ', blame.parent_hash, blame.commit_hash),
        }
        view:set_lines(new_lines)
        view:set_height(#new_lines)
    end
    return widget
end, 1)

return M
