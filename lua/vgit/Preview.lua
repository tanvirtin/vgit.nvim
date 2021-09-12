local Object = require('plenary.class')
local render_store = require('vgit.stores.render_store')
local events = require('vgit.events')
local logger = require('vgit.logger')
local sign = require('vgit.sign')
local virtual_text = require('vgit.virtual_text')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')
local scheduler = require('plenary.async.util').scheduler

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
        timer_id = nil,
    }, Preview)
end

function Preview:notify(text)
    local epoch = 2000
    if self.timer_id then
        vim.fn.timer_stop(self.timer_id)
        self.timer_id = nil
    end
    local popups = self:get_popups()
    if self.layout_type == 'vertical' then
        if popups.previous:has_custom_borders() then
            popups.previous:set_footer(text)
        end
        if popups.current:has_custom_borders() then
            popups.current:set_footer(text)
        end
    else
        if popups.preview:has_custom_borders() then
            popups.preview:set_footer(text)
        end
    end
    self.timer_id = vim.fn.timer_start(epoch, function()
        if self.layout_type == 'vertical' then
            pcall(popups.previous.set_footer, popups.previous)
            pcall(popups.current.set_footer, popups.current)
        else
            pcall(popups.preview.set_footer, popups.preview)
        end
        vim.fn.timer_stop(self.timer_id)
        self.timer_id = nil
    end)
end

function Preview:regenerate_win_toggle_queue()
    self.state.win_toggle_queue = self:get_win_ids()
end

function Preview:get_preview_win_ids()
    if self.layout_type == 'vertical' then
        return {
            self:get_popups().previous:get_virtual_line_nr_win_id(),
            self:get_popups().previous:get_win_id(),
            self:get_popups().current:get_virtual_line_nr_win_id(),
            self:get_popups().current:get_win_id(),
        }
    end
    return { self:get_popups().preview:get_win_id(), self:get_popups().preview:get_virtual_line_nr_win_id() }
end

function Preview:is_preview_focused()
    local preview_win_ids = self:get_preview_win_ids()
    local current_win_id = vim.api.nvim_get_current_win()
    for i = 1, #preview_win_ids do
        local win_id = preview_win_ids[i]
        if win_id == current_win_id then
            return true
        end
    end
    return false
end

function Preview:draw_changes(data)
    local lnum_changes = data.lnum_changes
    local layout_type = self.layout_type or 'horizontal'
    local popups = self:get_popups()
    local ns_id = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/paint')
    scheduler()
    for i = 1, #lnum_changes do
        scheduler()
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
        local type, lnum, word_diff = datum.type, datum.lnum, datum.word_diff
        local defined_sign = render_store.get('preview').sign.hls[type]
        if defined_sign then
            scheduler()
            sign.place(buf, lnum, defined_sign, render_store.get('preview').sign.priority)
            scheduler()
        end
        if type == 'void' then
            scheduler()
            local void_line = string.rep(
                render_store.get('preview').symbols.void,
                vim.api.nvim_win_get_width(popup:get_win_id())
            )
            scheduler()
            virtual_text.add(buf, ns_id, lnum - 1, 0, {
                id = lnum,
                virt_text = { { void_line, 'LineNr' } },
                virt_text_pos = 'overlay',
            })
            scheduler()
        end
        local texts = {}
        if word_diff then
            local offset = 0
            for j = 1, #word_diff do
                scheduler()
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
            scheduler()
            virtual_text.transpose_line(buf, texts, ns_id, lnum - 1)
            scheduler()
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
            scheduler()
            local lnum_change = data.lnum_changes[i]
            lnum_change_map[lnum_change.lnum] = lnum_change
        end
        for i = 1, #data.lines do
            scheduler()
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
        scheduler()
        popup:set_virtual_line_nr_lines(virtual_nr_lines, hls)
        scheduler()
        for i = 1, #data.lines do
            scheduler()
            local lnum_change = lnum_change_map[i]
            if lnum_change then
                local type, lnum = lnum_change.type, lnum_change.lnum
                local defined_sign = render_store.get('preview').sign.hls[type]
                if defined_sign then
                    scheduler()
                    sign.place(
                        popup:get_virtual_line_nr_buf(),
                        lnum,
                        defined_sign,
                        render_store.get('preview').sign.priority
                    )
                    scheduler()
                end
            end
        end
    elseif layout_type == 'vertical' then
        local previous_popup = popups.previous
        local current_popup = popups.current
        local current_lnum_change_map = {}
        local previous_lnum_change_map = {}
        for i = 1, #data.lnum_changes do
            scheduler()
            local lnum_change = data.lnum_changes[i]
            if lnum_change.buftype == 'current' then
                current_lnum_change_map[lnum_change.lnum] = lnum_change
            elseif lnum_change.buftype == 'previous' then
                previous_lnum_change_map[lnum_change.lnum] = lnum_change
            end
        end
        for i = 1, #data.current_lines do
            scheduler()
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
        scheduler()
        current_popup:set_virtual_line_nr_lines(virtual_nr_lines, hls)
        scheduler()
        for i = 1, #data.current_lines do
            scheduler()
            local lnum_change = current_lnum_change_map[i]
            if lnum_change then
                local type, lnum = lnum_change.type, lnum_change.lnum
                local defined_sign = render_store.get('preview').sign.hls[type]
                if defined_sign then
                    scheduler()
                    sign.place(
                        current_popup:get_virtual_line_nr_buf(),
                        lnum,
                        defined_sign,
                        render_store.get('preview').sign.priority
                    )
                    scheduler()
                end
            end
        end
        hls = {}
        virtual_nr_lines = {}
        line_nr_count = 1
        for i = 1, #data.previous_lines do
            scheduler()
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
        scheduler()
        previous_popup:set_virtual_line_nr_lines(virtual_nr_lines, hls)
        scheduler()
        for i = 1, #data.current_lines do
            scheduler()
            local lnum_change = previous_lnum_change_map[i]
            if lnum_change then
                local type, lnum = lnum_change.type, lnum_change.lnum
                local defined_sign = render_store.get('preview').sign.hls[type]
                if defined_sign then
                    scheduler()
                    sign.place(
                        previous_popup:get_virtual_line_nr_buf(),
                        lnum,
                        defined_sign,
                        render_store.get('preview').sign.priority
                    )
                    scheduler()
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
    if not self:is_mounted() then
        return self
    end
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
    for _, popup in pairs(self.popups) do
        local win_ids = popup:get_win_ids()
        local bufs = popup:get_bufs()
        for i = 1, #win_ids do
            if not vim.api.nvim_win_is_valid(win_ids[i]) then
                return false
            end
        end
        for i = 1, #bufs do
            if not buffer.is_valid(bufs[i]) then
                return false
            end
        end
    end
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
    local bufs = buffer.list()
    scheduler()
    for i = 1, #bufs do
        local buf = bufs[i]
        local is_buf_listed = buffer.get_option(buf, 'buflisted') == true
        scheduler()
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
