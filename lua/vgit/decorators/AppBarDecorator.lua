local Object = require('plenary.class')
local events = require('vgit.events')
local buffer = require('vgit.buffer')

local AppBarDecorator = Object:extend()

function AppBarDecorator:new(window_props, content_buf)
    return setmetatable({
        buf = nil,
        win_id = nil,
        content_buf = content_buf,
        window_props = window_props,
    }, AppBarDecorator)
end

function AppBarDecorator:mount()
    self.buf = vim.api.nvim_create_buf(true, true)
    buffer.assign_options(self.buf, {
        ['modifiable'] = false,
        ['bufhidden'] = 'wipe',
        ['buflisted'] = false,
    })
    self.win_id = vim.api.nvim_open_win(self.buf, false, {
        style = 'minimal',
        focusable = false,
        relative = self.window_props.relative,
        row = self.window_props.row,
        col = self.window_props.col,
        width = self.window_props.width,
        height = 1,
    })
    vim.api.nvim_win_set_option(self.win_id, 'cursorbind', false)
    vim.api.nvim_win_set_option(self.win_id, 'scrollbind', false)
    vim.api.nvim_win_set_option(self.win_id, 'winhl', 'Normal:StatusLine')
    events.buf.on(
        self.content_buf,
        'WinClosed',
        string.format(':lua require("vgit").renderer.hide_windows({ %s })', self.win_id),
        { once = true }
    )
    return self
end

function AppBarDecorator:set_lines(lines)
    buffer.set_lines(self.buf, lines)
end

function AppBarDecorator:get_win_id()
    return self.win_id
end

function AppBarDecorator:get_buf()
    return self.buf
end

return AppBarDecorator
