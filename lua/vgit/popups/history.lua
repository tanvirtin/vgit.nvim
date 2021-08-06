local State = require('vgit.State')
local highlighter = require('vgit.highlighter')
local localization = require('vgit.localization')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local sign = require('vgit.sign')
local a = require('plenary.async')
local t = localization.translate
local wrap = a.wrap
local void = a.void
local scheduler = a.util.scheduler

local vim = vim

local function global_width()
    return vim.o.columns
end

local function global_height()
    return vim.o.lines
end

local M = {}

M.constants = {
    history_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/history'),
}

M.state = State.new({
    priority = 10,
    signs = {
        add = 'VGitViewSignAdd',
        remove = 'VGitViewSignRemove',
    },
    indicator = {
        hl = 'VGitIndicator',
    },
    horizontal_window = {
        title = t('history/horizontal'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    current_window = {
        title = t('history/current'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    previous_window = {
        title = t('history/previous'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
    history_window = {
        title = t('history/history'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus',
    },
})

M.setup = function(config)
    M.state:assign(config)
end

local function colorize_buf(lnum_changes, callback)
    for i = 1, #lnum_changes do
        local datum = lnum_changes[i]
        sign.place(callback(datum), datum.lnum, M.state:get('signs')[datum.type], M.state:get('priority'))
    end
end

local function colorize_indicator(buf, lnum)
    highlighter.highlight(buf, M.constants.history_namespace, M.state:get('indicator').hl, { lnum, 0 }, { lnum, 1 })
end

local function change_history_indicator(lines, selected)
    for i = 1, #lines do
        local line = lines[i]
        if i == selected then
            lines[i] = string.format('>%s', line:sub(2, #line))
        else
            lines[i] = string.format(' %s', line:sub(2, #line))
        end
    end
    return lines
end

local function create_horizontal_widget(opts)
    local height = math.ceil(global_height() - 13)
    local width = math.ceil(global_width() * 0.8)
    local col = math.ceil((global_width() - width) / 2) - 1
    local views = {
        preview = View.new({
            filetype = opts.filetype,
            border = M.state:get('horizontal_window').border,
            border_hl = M.state:get('horizontal_window').border_hl,
            border_focus_hl = M.state:get('horizontal_window').border_focus_hl,
            title = M.state:get('horizontal_window').title,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
                ['signcolumn'] = 'yes',
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col,
            },
        }),
        history = View.new({
            title = M.state:get('history_window').title,
            border = M.state:get('history_window').border,
            border_hl = M.state:get('history_window').border_hl,
            border_focus_hl = M.state:get('history_window').border_focus_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = 7,
                row = height + 3,
                col = col,
            },
        }),
    }
    return Widget.new(views, 'horizontal_history')
end

local function create_vertical_widget(opts)
    local height = math.ceil(global_height() - 13)
    local width = math.ceil(global_width() * 0.485)
    local col = math.ceil((global_width() - (width * 2)) / 2) - 1
    local views = {
        previous = View.new({
            filetype = opts.filetype,
            border = M.state:get('previous_window').border,
            border_hl = M.state:get('previous_window').border_hl,
            border_focus_hl = M.state:get('previous_window').border_focus_hl,
            title = M.state:get('previous_window').title,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['signcolumn'] = 'yes',
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col,
            },
        }),
        current = View.new({
            filetype = opts.filetype,
            title = M.state:get('current_window').title,
            border = M.state:get('current_window').border,
            border_hl = M.state:get('current_window').border_hl,
            border_focus_hl = M.state:get('current_window').border_focus_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['signcolumn'] = 'yes',
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col + width + 2,
            },
        }),
        history = View.new({
            title = M.state:get('history_window').title,
            border = M.state:get('history_window').border,
            border_hl = M.state:get('history_window').border_hl,
            border_focus_hl = M.state:get('history_window').border_focus_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width * 2 + 2,
                height = 7,
                row = height + 3,
                col = col,
            },
        }),
    }
    return Widget.new(views, 'vertical_history')
end

local function create_history_lines(logs)
    local padding_right = 2
    local table_title_space = { padding_right, padding_right, padding_right, padding_right, 0 }
    local rows = {}
    for i = 1, #logs do
        local log = logs[i]
        local row = {
            i - 1 == 0 and string.format('>  HEAD~%s', i - 1) or string.format('   HEAD~%s', i - 1),
            log.author_name or '',
            log.commit_hash or '',
            log.summary or '',
            (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp))) or '',
        }
        for j = 1, #row do
            local item = row[j]
            if #item + 1 > table_title_space[j] then
                table_title_space[j] = #item + padding_right
            end
        end
        rows[#rows + 1] = row
    end
    local history_lines = {}
    for i = 1, #rows do
        local row = rows[i]
        local line = ''
        for j = 1, #row do
            local item = row[j]
            line = line .. item .. string.rep(' ', table_title_space[j] - #item)
            if j ~= #table_title_space then
                line = line
            end
        end
        history_lines[#history_lines + 1] = line
    end
    return history_lines
end

M.show_horizontal = wrap(function(fetch, filetype)
    local parent_buf = vim.api.nvim_get_current_buf()
    local widget = create_horizontal_widget({ filetype = filetype })
    widget:render():set_loading(true)
    local views = widget:get_views()
    views.history:focus()
    scheduler()
    local err, data = fetch()
    scheduler()
    widget:set_loading(false)
    scheduler()
    if err then
        local no_commits_str = 'does not have any commits yet'
        if
            type(err) == 'table'
            and #err > 0
            and type(err[1]) == 'string'
            and err[1]:sub(#err[1] - #no_commits_str + 1, #err[1]) == no_commits_str
        then
            widget:set_centered_text(t('history/no_commits'))
            return widget
        end
        widget:set_error(true)
        scheduler()
        return widget
    end
    views.preview:set_lines(data.lines)
    views.history:set_lines(create_history_lines(data.logs))
    views.history:add_keymap('<enter>', string.format('_change_history(%s)', parent_buf))
    colorize_buf(data.lnum_changes, function()
        return views.preview:get_buf()
    end)
    colorize_indicator(views.history:get_buf(), 0)
    return widget
end, 2)

M.show_vertical = wrap(function(fetch, filetype)
    local parent_buf = vim.api.nvim_get_current_buf()
    local widget = create_vertical_widget({ filetype = filetype })
    widget:render():set_loading(true)
    local views = widget:get_views()
    views.history:focus()
    scheduler()
    local err, data = fetch()
    scheduler()
    widget:set_loading(false)
    scheduler()
    if err then
        local no_commits_str = 'does not have any commits yet'
        if
            type(err) == 'table'
            and #err > 0
            and type(err[1]) == 'string'
            and err[1]:sub(#err[1] - #no_commits_str + 1, #err[1]) == no_commits_str
        then
            widget:set_centered_text(t('history/no_commits'))
            return widget
        end
        widget:set_error(true)
        scheduler()
        return widget
    end
    views.previous:set_lines(data.previous_lines)
    views.current:set_lines(data.current_lines)
    views.history:set_lines(create_history_lines(data.logs))
    views.history:add_keymap('<enter>', string.format('_change_history(%s)', parent_buf))
    colorize_buf(data.lnum_changes, function(datum)
        return views[datum.buftype]:get_buf()
    end)
    colorize_indicator(views.history:get_buf(), 0)
    return widget
end, 2)

M.change_horizontal = void(function(widget, fetch, selected_log)
    local views = widget:get_views()
    sign.unplace(views.preview:get_buf())
    views.preview:set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    views.preview:set_loading(false)
    scheduler()
    if err then
        views.preview:set_error(true)
        scheduler()
        return
    end
    vim.api.nvim_win_set_cursor(views.preview:get_win_id(), { 1, 0 })
    colorize_buf(data.lnum_changes, function()
        return views.preview:get_buf()
    end)
    views.preview:set_lines(data.lines)
    local history_lines = change_history_indicator(views.history:get_lines(), selected_log)
    views.history:set_lines(history_lines)
    colorize_indicator(views.history:get_buf(), selected_log - 1)
end)

M.change_vertical = void(function(widget, fetch, selected_log)
    local views = widget:get_views()
    sign.unplace(views.previous:get_buf())
    sign.unplace(views.current:get_buf())
    views.previous:set_loading(true)
    views.current:set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    views.previous:set_loading(false)
    views.current:set_loading(false)
    scheduler()
    if err then
        views.previous:set_error(true)
        views.current:set_error(true)
        scheduler()
        return
    end
    vim.api.nvim_win_set_cursor(views.previous:get_win_id(), { 1, 0 })
    vim.api.nvim_win_set_cursor(views.current:get_win_id(), { 1, 0 })
    colorize_buf(data.lnum_changes, function(datum)
        return views[datum.buftype]:get_buf()
    end)
    views.current:set_lines(data.current_lines)
    views.previous:set_lines(data.previous_lines)
    local history_lines = change_history_indicator(views.history:get_lines(), selected_log)
    views.history:set_lines(history_lines)
    colorize_indicator(views.history:get_buf(), selected_log - 1)
end)

return M
