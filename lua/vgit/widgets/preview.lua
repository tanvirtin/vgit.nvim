local State = require('vgit.State')
local localization = require('vgit.localization')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local sign = require('vgit.sign')
local a = require('plenary.async')
local t = localization.translate
local wrap = a.wrap
local scheduler = a.util.scheduler

local vim = vim

local function global_width()
    return vim.o.columns
end

local function global_height()
    return vim.o.lines
end

local M = {}

M.state = State.new({
    priority = 10,
    horizontal_window = {
        title = t('preview/horizontal'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus'
    },
    current_window = {
        title = t('preview/current'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus'
    },
    previous_window = {
        title = t('preview/previous'),
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'VGitBorder',
        border_focus_hl = 'VGitBorderFocus'
    },
    signs = {
        add = 'VGitViewSignAdd',
        remove = 'VGitViewSignRemove',
    },
})

M.setup = function(config)
    M.state:assign(config)
end

M.render_horizontal = wrap(function(widget_name, fetch, filetype)
    local height = math.ceil(global_height() - 4)
    local width = math.ceil(global_width() * 0.8)
    local col = math.ceil((global_width() - width) / 2) - 1
    local views = {
        preview = View.new({
            filetype = filetype,
            title = M.state:get('horizontal_window').title,
            border = M.state:get('horizontal_window').border,
            border_hl = M.state:get('horizontal_window').border_hl,
            border_focus_hl = M.state:get('horizontal_window').border_focus_hl,
            win_options = {
                ['cursorline'] = true,
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
    }
    local widget = Widget.new(views, widget_name)
        :render()
        :set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    widget:set_loading(false)
    scheduler()
    if not err then
        views.preview:set_lines(data.lines)
        for i = 1, #data.lnum_changes do
            local datum = data.lnum_changes[i]
           sign.place(
                views.preview:get_buf(),
                datum.lnum,
                M.state:get('signs')[datum.type],
                M.state:get('priority')
            )
        end
    else
        widget:set_error(true)
        scheduler()
    end
    return widget
end, 3)

M.render_vertical = wrap(function(widget_name, fetch, filetype)
    local height = math.ceil(global_height() - 4)
    local width = math.ceil(global_width() * 0.485)
    local col = math.ceil((global_width() - (width * 2)) / 2) - 1
    local views = {
        previous = View.new({
            filetype = filetype,
            title = M.state:get('previous_window').title,
            border = M.state:get('previous_window').border,
            border_hl = M.state:get('previous_window').border_hl,
            border_focus_hl = M.state:get('previous_window').border_focus_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
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
            filetype = filetype,
            title = M.state:get('current_window').title,
            border = M.state:get('current_window').border,
            border_hl = M.state:get('current_window').border_hl,
            border_focus_hl = M.state:get('current_window').border_focus_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col + width + 2,
            },
        })
    }
    local widget = Widget.new(views, widget_name)
        :render()
        :set_loading(true)
    views.current:focus()
    scheduler()
    local err, data = fetch()
    scheduler()
    widget:set_loading(false)
    scheduler()
    if not err then
        views.previous:set_lines(data.previous_lines)
        views.current:set_lines(data.current_lines)
        for i = 1, #data.lnum_changes do
            local datum = data.lnum_changes[i]
            sign.place(
                views[datum.buftype]:get_buf(),
                datum.lnum,
                M.state:get('signs')[datum.type],
                M.state:get('priority')
            )
        end
    else
        widget:set_error(true)
        scheduler()
    end
    return widget
end, 3)

return M
