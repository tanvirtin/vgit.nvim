local Object = require('plenary.class')
local events = require('vgit.events')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')

local Widget = Object:extend()

function Widget:new(views, opts)
    assert(type(views) == 'table', 'type error :: expected table')
    assert(type(opts) == 'table' or type(opts) == 'nil', 'type error :: expected string or nil')
    return setmetatable({
        views = views,
        state = { mounted = false },
        popup = opts and opts.popup or false,
        parent_buf = vim.api.nvim_get_current_buf(),
        parent_win = vim.api.nvim_get_current_win(),
    }, Widget)
end

function Widget:set_loading(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    for _, v in pairs(self.views) do
        v:set_loading(value)
    end
    return self
end

function Widget:set_centered_text(text)
    assert(type(text) == 'string', 'type error :: expected string')
    for _, v in pairs(self.views) do
        v:set_centered_text(text)
    end
    return self
end

function Widget:set_error(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    for _, v in pairs(self.views) do
        v:set_error(value)
    end
    return self
end

function Widget:get_views()
    return self.views
end

function Widget:get_parent_buf()
    return self.parent_buf
end

function Widget:get_parent_win()
    return self.parent_win
end

function Widget:get_win_ids()
    local win_ids = {}
    for _, v in pairs(self.views) do
        win_ids[#win_ids + 1] = v:get_win_id()
    end
    return win_ids
end

function Widget:get_bufs()
    local bufs = {}
    for _, v in pairs(self.views) do
        bufs[#bufs + 1] = v:get_buf()
    end
    return bufs
end

function Widget:clear()
    for _, v in pairs(self.views) do
        v:clear()
    end
end

function Widget:is_mounted()
    return self.state.mounted
end

function Widget:mount()
    if self.state.mounted then
        return self
    end
    for _, v in pairs(self.views) do
        v:mount()
    end
    local win_ids = {}
    for _, v in pairs(self.views) do
        win_ids[#win_ids + 1] = v:get_win_id()
        win_ids[#win_ids + 1] = v:get_border_win_id()
    end
    for _, v in pairs(self.views) do
        v:on('BufWinLeave', string.format(':lua require("vgit").ui.close_windows(%s)', vim.inspect(win_ids)))
    end
    local bufs = vim.api.nvim_list_bufs()
    for i = 1, #bufs do
        local buf = bufs[i]
        local is_buf_listed = vim.api.nvim_buf_get_option(buf, 'buflisted') == true
        if is_buf_listed and buffer.is_valid(buf) then
            local event = self.popup and 'BufEnter' or 'BufWinEnter'
            events.buf.on(buf, event, string.format(':lua require("vgit").ui.close_windows(%s)', vim.inspect(win_ids)))
        end
    end
    self.state.mounted = true
    return self
end

function Widget:unmount()
    local views = self:get_views()
    for _, view in pairs(views) do
        view:unmount()
    end
    self.mounted = false
end

return Widget
