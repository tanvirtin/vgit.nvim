local Object = require('plenary.class')
local events = require('vgit.events')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')

local Preview = Object:extend()

function Preview:new(popups, opts)
    assert(type(popups) == 'table', 'type error :: expected table')
    assert(type(opts) == 'table' or type(opts) == 'nil', 'type error :: expected string or nil')
    return setmetatable({
        popups = popups,
        state = {
            mounted = false,
            win_toggle_queue = {},
        },
        temporary = opts and opts.temporary or false,
        parent_buf = vim.api.nvim_get_current_buf(),
        parent_win = vim.api.nvim_get_current_win(),
        layout_type = opts and opts.layout_type or nil,
        data = nil,
        err = nil,
    }, Preview)
end

function Preview:regenerate_win_toggle_queue()
    self.state.win_toggle_queue = self:get_win_ids()
end

function Preview:make_virtual_line_nr(data, layout_type)
    local popups = self:get_popups()
    local line_nr_count = 1
    local virtual_nr_lines = {}
    if layout_type == 'horizontal' then
        local lnum_change_map = {}
        for i = 1, #data.lnum_changes do
            local lnum_change = data.lnum_changes[i]
            lnum_change_map[lnum_change.lnum] = lnum_change
        end
        for i = 1, #data.lines do
            local lnum_change = lnum_change_map[i]
            if lnum_change and lnum_change.type == 'remove' then
                virtual_nr_lines[#virtual_nr_lines + 1] = ''
            else
                virtual_nr_lines[#virtual_nr_lines + 1] = string.format('%s', line_nr_count)
                line_nr_count = line_nr_count + 1
            end
        end
        popups.preview:set_virtual_line_nr_lines(virtual_nr_lines)
    elseif layout_type == 'vertical' then
        local current_lnum_change_map = {}
        local previous_lnum_change_map = {}
        for i = 1, #data.lnum_changes do
            local lnum_change = data.lnum_changes[i]
            if lnum_change.buftype == 'current' then
                current_lnum_change_map[lnum_change.lnum] = lnum_change
            elseif lnum_change.buftype == 'previous' then
                previous_lnum_change_map[lnum_change.lnum] = lnum_change
            end
        end
        for i = 1, #data.current_lines do
            local lnum_change = current_lnum_change_map[i]
            if lnum_change and (lnum_change.type == 'remove' or lnum_change.type == 'void') then
                virtual_nr_lines[#virtual_nr_lines + 1] = ''
            else
                virtual_nr_lines[#virtual_nr_lines + 1] = string.format('%s', line_nr_count)
                line_nr_count = line_nr_count + 1
            end
        end
        popups.current:set_virtual_line_nr_lines(virtual_nr_lines)
        virtual_nr_lines = {}
        line_nr_count = 1
        for i = 1, #data.previous_lines do
            local lnum_change = previous_lnum_change_map[i]
            if lnum_change and (lnum_change.type == 'add' or lnum_change.type == 'void') then
                virtual_nr_lines[#virtual_nr_lines + 1] = ''
            else
                virtual_nr_lines[#virtual_nr_lines + 1] = string.format('%s', line_nr_count)
                line_nr_count = line_nr_count + 1
            end
        end
        popups.previous:set_virtual_line_nr_lines(virtual_nr_lines)
    end
end

function Preview:get_next_win_id()
    if vim.tbl_isempty(self.state.win_toggle_queue) then
        self:regenerate_win_toggle_queue()
    end
    return table.remove(self.state.win_toggle_queue)
end

function Preview:set_loading(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    for _, popup in pairs(self.popups) do
        popup:set_loading(value)
    end
    return self
end

function Preview:set_centered_text(text)
    assert(type(text) == 'string', 'type error :: expected string')
    for _, popup in pairs(self.popups) do
        popup:set_centered_text(text)
    end
    return self
end

function Preview:set_error(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    for _, popup in pairs(self.popups) do
        popup:set_error(value)
    end
    return self
end

function Preview:get_popups()
    return self.popups
end

function Preview:get_parent_buf()
    return self.parent_buf
end

function Preview:get_parent_win()
    return self.parent_win
end

function Preview:get_win_ids()
    local win_ids = {}
    for _, popup in pairs(self.popups) do
        win_ids[#win_ids + 1] = popup:get_win_id()
    end
    return win_ids
end

function Preview:get_bufs()
    local bufs = {}
    for _, popup in pairs(self.popups) do
        bufs[#bufs + 1] = popup:get_buf()
    end
    return bufs
end

function Preview:clear()
    for _, popup in pairs(self.popups) do
        popup:clear()
    end
end

function Preview:is_mounted()
    return self.state.mounted
end

function Preview:is_temporary()
    return self.temporary
end

function Preview:mount()
    if self.state.mounted then
        return self
    end
    for _, popup in pairs(self.popups) do
        popup:mount()
    end
    local win_ids = {}
    for _, popup in pairs(self.popups) do
        win_ids[#win_ids + 1] = popup:get_win_id()
        win_ids[#win_ids + 1] = popup:get_border_win_id()
        if popup:has_virtual_line_nr() then
            win_ids[#win_ids + 1] = popup:get_virtual_line_nr_win_id()
        end
    end
    for _, popup in pairs(self.popups) do
        popup:on(
            'BufWinLeave',
            string.format(':lua require("vgit").renderer.hide_windows(%s)', vim.inspect(win_ids)),
            { once = true }
        )
    end
    local bufs = vim.api.nvim_list_bufs()
    for i = 1, #bufs do
        local buf = bufs[i]
        local is_buf_listed = vim.api.nvim_buf_get_option(buf, 'buflisted') == true
        if is_buf_listed and buffer.is_valid(buf) then
            local event = self.temporary and 'BufEnter' or 'BufWinEnter'
            events.buf.on(
                buf,
                event,
                string.format(':lua require("vgit").renderer.hide_windows(%s)', vim.inspect(win_ids)),
                { once = true }
            )
        end
    end
    self.state.mounted = true
    return self
end

function Preview:unmount()
    local popups = self:get_popups()
    for _, popup in pairs(popups) do
        popup:unmount()
    end
    self.state.mounted = false
end

function Preview:render()
    error('Preview must implement render method')
end

return Preview
