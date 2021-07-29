local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')

local vim = vim

local Widget = {}
Widget.__index = Widget

local function new(views, name)
    assert(type(views) == 'table', 'type error :: expected table')
    assert(type(name) == 'string', 'type error :: expected string')
    return setmetatable({
        name = name,
        views = views,
        state = { rendered = false },
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

function Widget:get_name()
    return self.name
end

function Widget:get_views()
    return self.views
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

function Widget:render(as_popup)
    assert(type(as_popup) == 'boolean' or type(as_popup) == 'nil', 'type error :: expected nil or boolean')
    if self.state.rendered then
        return self
    end
    for _, v in pairs(self.views) do
        v:render()
    end
    local win_ids = {}
    for _, v in pairs(self.views) do
        win_ids[#win_ids + 1] = v:get_win_id()
        win_ids[#win_ids + 1] = v:get_border_win_id()
    end
    for _, v in pairs(self.views) do
        v:add_autocmd(
            'BufWinLeave', string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(win_ids))
        )
    end
    local bufs = vim.api.nvim_list_bufs()
    for i = 1, #bufs do
        local buf = bufs[i]
        local is_buf_listed = vim.api.nvim_buf_get_option(buf, 'buflisted') == true
        if is_buf_listed and buffer.is_valid(buf) then
            local event = as_popup and 'BufEnter' or 'BufWinEnter'
            buffer.add_autocmd(
                buf,
                event,
                string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(win_ids))
            )
        end
    end
    self.state.rendered = true
    return self
end

return {
    new = new,
    __object = Widget,
}
