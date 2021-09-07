local Object = require('plenary.class')
local render_store = require('vgit.stores.render_store')
local events = require('vgit.events')
local logger = require('vgit.logger')
local sign = require('vgit.sign')
local virtual_text = require('vgit.virtual_text')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')

local Preview = Object:extend()

function Preview:new(popups, opts)
    assert(type(popups) == 'table', 'type error :: expected table')
    assert(type(opts) == 'table' or type(opts) == 'nil', 'type error :: expected string or nil')
    opts = opts or {}
    return setmetatable({
        popups = popups,
        state = {
            mounted = false,
            rendered = false,
            win_toggle_queue = {},
        },
        parent_buf = vim.api.nvim_get_current_buf(),
        parent_win = vim.api.nvim_get_current_win(),
        temporary = opts.temporary or false,
        layout_type = opts.layout_type or nil,
        selected = opts.selected or nil,
        data = nil,
        err = nil,
    }, Preview)
end

function Preview:regenerate_win_toggle_queue()
    self.state.win_toggle_queue = self:get_win_ids()
end

function Preview:draw_changes(data)
    local lnum_changes = data.lnum_changes
    local layout_type = self.layout_type or 'horizontal'
    local popups = self:get_popups()
    local ns_id = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/paint')
    for i = 1, #lnum_changes do
        local datum, popup, buf = lnum_changes[i], nil, nil
        if layout_type == 'horizontal' then
            popup = popups.preview
            buf = popup:get_buf()
        elseif layout_type == 'vertical' then
            popup = popups[datum.buftype]
            buf = popup:get_buf()
        end
        if not buf or not popup then
            logger.error('There are no popup or buffer to draw the changes')
            return
        end
        popup:focus()
        local type, lnum, word_diff = datum.type, datum.lnum, datum.word_diff
        local defined_sign = render_store.get('preview').sign.hls[type]
        if defined_sign then
            sign.place(buf, lnum, defined_sign, render_store.get('preview').sign.priority)
        end
        if type == 'void' then
            local void_line = string.rep(render_store.get('preview').symbols.void, vim.api.nvim_win_get_width(0))
            virtual_text.add(buf, ns_id, lnum - 1, 0, {
                id = lnum,
                virt_text = { { void_line, 'LineNr' } },
                virt_text_pos = 'overlay',
            })
        end
        local texts = {}
        if word_diff then
            local offset = 0
            for j = 1, #word_diff do
                local segment = word_diff[j]
                local operation, fragment = unpack(segment)
                if operation == -1 then
                    local hl = type == 'remove' and 'VGitViewWordRemove' or 'VGitViewWordAdd'
                    texts[#texts + 1] = { fragment, hl }
                elseif operation == 0 then
                    texts[#texts + 1] = {
                        fragment,
                        nil,
                    }
                end
                if operation == 0 or operation == -1 then
                    offset = offset + #fragment
                end
            end
            virtual_text.transpose_line(buf, texts, ns_id, lnum - 1)
        end
    end
end

function Preview:make_virtual_line_nr(data)
    local popups = self:get_popups()
    local line_nr_count = 1
    local virtual_nr_lines = {}
    local hls = {}
    local common_hl = 'LineNr'
    local layout_type = self.layout_type or 'horizontal'
    if layout_type == 'horizontal' then
        local popup = popups.preview
        local lnum_change_map = {}
        for i = 1, #data.lnum_changes do
            local lnum_change = data.lnum_changes[i]
            lnum_change_map[lnum_change.lnum] = lnum_change
        end
        for i = 1, #data.lines do
            local lnum_change = lnum_change_map[i]
            if lnum_change and lnum_change.type == 'remove' then
                virtual_nr_lines[#virtual_nr_lines + 1] = ''
                hls[#hls + 1] = common_hl
            else
                virtual_nr_lines[#virtual_nr_lines + 1] = string.format('%s', line_nr_count)
                hls[#hls + 1] = common_hl
                if lnum_change and lnum_change.type == 'add' then
                    hls[#hls] = render_store.get('sign').hls.add
                elseif lnum_change and lnum_change.type == 'remove' then
                    hls[#hls] = render_store.get('sign').hls.remove
                end
                line_nr_count = line_nr_count + 1
            end
        end
        popup:set_virtual_line_nr_lines(virtual_nr_lines, hls)
        for i = 1, #data.lines do
            local lnum_change = lnum_change_map[i]
            if lnum_change then
                local type, lnum = lnum_change.type, lnum_change.lnum
                local defined_sign = render_store.get('preview').sign.hls[type]
                if defined_sign then
                    sign.place(
                        popup:get_virtual_line_nr_buf(),
                        lnum,
                        defined_sign,
                        render_store.get('preview').sign.priority
                    )
                end
            end
        end
    elseif layout_type == 'vertical' then
        local previous_popup = popups.previous
        local current_popup = popups.current
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
                virtual_nr_lines[#virtual_nr_lines + 1] = string.rep(render_store.get('preview').symbols.void, 6)
                hls[#hls + 1] = common_hl
            else
                virtual_nr_lines[#virtual_nr_lines + 1] = string.format('%s', line_nr_count)
                hls[#hls + 1] = common_hl
                if lnum_change and lnum_change.type == 'add' then
                    hls[#hls] = render_store.get('sign').hls.add
                elseif lnum_change and lnum_change.type == 'remove' then
                    hls[#hls] = render_store.get('sign').hls.remove
                end
                line_nr_count = line_nr_count + 1
            end
        end
        current_popup:set_virtual_line_nr_lines(virtual_nr_lines, hls)
        for i = 1, #data.current_lines do
            local lnum_change = current_lnum_change_map[i]
            if lnum_change then
                local type, lnum = lnum_change.type, lnum_change.lnum
                local defined_sign = render_store.get('preview').sign.hls[type]
                if defined_sign then
                    sign.place(
                        current_popup:get_virtual_line_nr_buf(),
                        lnum,
                        defined_sign,
                        render_store.get('preview').sign.priority
                    )
                end
            end
        end
        hls = {}
        virtual_nr_lines = {}
        line_nr_count = 1
        for i = 1, #data.previous_lines do
            local lnum_change = previous_lnum_change_map[i]
            if lnum_change and (lnum_change.type == 'add' or lnum_change.type == 'void') then
                virtual_nr_lines[#virtual_nr_lines + 1] = string.rep(render_store.get('preview').symbols.void, 6)
                hls[#hls + 1] = common_hl
            else
                virtual_nr_lines[#virtual_nr_lines + 1] = string.format('%s', line_nr_count)
                hls[#hls + 1] = common_hl
                if lnum_change and lnum_change.type == 'add' then
                    hls[#hls] = render_store.get('sign').hls.add
                elseif lnum_change and lnum_change.type == 'remove' then
                    hls[#hls] = render_store.get('sign').hls.remove
                end
                line_nr_count = line_nr_count + 1
            end
        end
        previous_popup:set_virtual_line_nr_lines(virtual_nr_lines, hls)
        for i = 1, #data.current_lines do
            local lnum_change = previous_lnum_change_map[i]
            if lnum_change then
                local type, lnum = lnum_change.type, lnum_change.lnum
                local defined_sign = render_store.get('preview').sign.hls[type]
                if defined_sign then
                    sign.place(
                        previous_popup:get_virtual_line_nr_buf(),
                        lnum,
                        defined_sign,
                        render_store.get('preview').sign.priority
                    )
                end
            end
        end
    end
end

function Preview:get_next_win_id()
    if vim.tbl_isempty(self.state.win_toggle_queue) then
        self:regenerate_win_toggle_queue()
    end
    return table.remove(self.state.win_toggle_queue)
end

function Preview:set_loading(value, force)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    for _, popup in pairs(self.popups) do
        popup:set_loading(value, force)
    end
    return self
end

function Preview:set_centered_text(text, force)
    assert(type(text) == 'string', 'type error :: expected string')
    for _, popup in pairs(self.popups) do
        popup:set_centered_text(text, force)
    end
    return self
end

function Preview:set_error(value, force)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    for _, popup in pairs(self.popups) do
        popup:set_error(value, force)
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

function Preview:is_mounted()
    return self.state.mounted
end

function Preview:is_temporary()
    return self.temporary
end

function Preview:set_mounted(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    self.state.mounted = value
end

function Preview:clear()
    for _, popup in pairs(self.popups) do
        popup:clear()
    end
end

function Preview:mount()
    if self:is_mounted() then
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
    self:set_mounted(true)
    return self
end

function Preview:unmount()
    local popups = self:get_popups()
    for _, popup in pairs(popups) do
        popup:unmount()
    end
    self:set_mounted(false)
end

function Preview:render()
    error('Preview must implement render method')
end

return Preview
