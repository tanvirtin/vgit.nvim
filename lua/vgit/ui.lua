local State = require('vgit.State')
local preview_widget = require('vgit.widgets.preview')
local history_widget = require('vgit.widgets.history')
local hunk_widget = require('vgit.widgets.hunk')
local blame_widget = require('vgit.widgets.blame')
local buffer = require('vgit.buffer')
local sign = require('vgit.sign')
local a = require('plenary.async')
local void = a.void
local scheduler = a.util.scheduler

local vim = vim

local function round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

local M = {}

M.constants = {
    blame_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/blame'),
    blame_line_id = 1,
}

M.state = State.new({
    mounted_widget = {},
    blame_line = {
        hl = 'VGitBlame',
        format = function(blame, git_config)
            local config_author = git_config['user.name']
            local author = blame.author
            if config_author == author then
                author = 'You'
            end
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
                author = 'You'
                commit_message = 'Uncommitted changes'
                local info = string.format('%s • %s', author, commit_message)
                return string.format(' %s', info)
            end
            local max_commit_message_length = 255
            if #commit_message > max_commit_message_length then
                commit_message = commit_message:sub(1, max_commit_message_length) .. '...'
            end
            local info = string.format('%s, %s • %s', author, time_format, commit_message)
            return string.format(' %s', info)
        end
    },
    hunk_sign = {
        priority = 10,
        signs = {
            add = 'VGitSignAdd',
            remove = 'VGitSignRemove',
            change = 'VGitSignChange',
        },
    },
})

M.setup = function(config)
    M.state:assign(config)
    preview_widget.setup(config.preview)
    history_widget.setup(config.history)
    hunk_widget.setup(config.hunk)
    blame_widget.setup(config.blame)
end

M.close_windows = function(wins)
    M.state:set('mounted_widget', {})
    local existing_wins = vim.api.nvim_list_wins()
    for i = 1, #wins do
        local win = wins[i]
        if vim.api.nvim_win_is_valid(win) and vim.tbl_contains(existing_wins, win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
end

M.get_mounted_widget = function()
    return M.state:get('mounted_widget')
end

M.show_blame_line = function(buf, blame, lnum, git_config)
    if buffer.is_valid(buf) then
        local virt_text = M.state:get('blame_line').format(blame, git_config)
        if type(virt_text) == 'string' then
            pcall(vim.api.nvim_buf_set_extmark, buf, M.constants.blame_namespace, lnum - 1, 0, {
                id = M.constants.blame_line_id,
                virt_text = { { virt_text, M.state:get('blame_line').hl } },
                virt_text_pos = 'eol',
            })
        end
    end
end

M.hide_blame_line = function(buf)
    if buffer.is_valid(buf) then
        pcall(vim.api.nvim_buf_del_extmark, buf, M.constants.blame_namespace, M.constants.blame_line_id)
    end
end

M.show_hunk_signs = void(function(buf, hunks)
    scheduler()
    if buffer.is_valid(buf) then
        for i = 1, #hunks do
            local hunk = hunks[i]
            for j = hunk.start, hunk.finish do
                sign.place(
                    buf,
                    (hunk.type == 'remove' and j == 0) and 1 or j,
                    M.state:get('hunk_sign').signs[hunk.type],
                    M.state:get('hunk_sign').priority
                )
                scheduler()
            end
            scheduler()
        end
    end
end)

M.hide_hunk_signs = void(function(buf)
    scheduler()
    if buffer.is_valid(buf) then
        sign.unplace(buf)
        scheduler()
    end
end)

M.show_blame = void(function(fetch)
    local widget = blame_widget.render(fetch)
    M.state:set('mounted_widget', widget)
end)

M.show_hunk = function(hunk_info, filetype)
    local widget = hunk_widget.render(hunk_info, filetype)
    M.state:set('mounted_widget', widget)
end

M.show_horizontal_preview = void(function(widget_name, fetch, filetype)
    local widget = preview_widget.render_horizontal(widget_name, fetch, filetype)
    M.state:set('mounted_widget', widget)
end)

M.show_vertical_preview = void(function(widget_name, fetch, filetype)
    local widget = preview_widget.render_vertical(widget_name, fetch, filetype)
    M.state:set('mounted_widget', widget)
end)

M.show_horizontal_history = void(function(fetch, filetype)
    local widget = history_widget.render_horizontal(fetch, filetype)
    M.state:set('mounted_widget', widget)
end)

M.show_vertical_history = void(function(fetch, filetype)
    local widget = history_widget.render_vertical(fetch, filetype)
    M.state:set('mounted_widget', widget)
end)

M.change_horizontal_history = void(function(fetch, selected_log)
    local widget = M.state:get('mounted_widget')
    history_widget.change_horizontal(widget, fetch, selected_log)
end)

M.change_vertical_history = void(function(fetch, selected_log)
    local widget = M.state:get('mounted_widget')
    history_widget.change_vertical(widget, fetch, selected_log)
end)

return M
