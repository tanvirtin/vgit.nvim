local Object = require('plenary.class')
local render_store = require('vgit.stores.render_store')
local events = require('vgit.events')
local logger = require('vgit.logger')
local sign = require('vgit.sign')
local virtual_text = require('vgit.virtual_text')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')
local scheduler = require('plenary.async.util').scheduler
local navigation = require('vgit.navigation')
local CodeComponent = require('vgit.components.CodeComponent')

local Preview = Object:extend()

function Preview:new(components, opts)
    assert(type(components) == 'table', 'type error :: expected table')
    assert(type(opts) == 'table' or type(opts) == 'nil', 'type error :: expected string or nil')
    opts = opts or {}
    return setmetatable({
        components = components,
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
    local components = self:get_components()
    if self.layout_type == 'vertical' then
        if components.previous:has_border() then
            components.previous:set_footer(text)
        end
        if components.current:has_border() then
            components.current:set_footer(text)
        end
    else
        if components.preview:has_border() then
            components.preview:set_footer(text)
        end
    end
    self.timer_id = vim.fn.timer_start(epoch, function()
        if self.layout_type == 'vertical' then
            pcall(components.previous.set_footer, components.previous)
            pcall(components.current.set_footer, components.current)
        else
            pcall(components.preview.set_footer, components.preview)
        end
        vim.fn.timer_stop(self.timer_id)
        self.timer_id = nil
    end)
end

function Preview:navigate_code(direction)
    if not self.data then
        return
    end
    if not self.data.diff_change then
        return
    end
    if not self.data.diff_change.marks then
        return
    end
    local components = self:get_components()
    local code_win_ids = {}
    local current_win_id = vim.api.nvim_get_current_win()
    if self.layout_type == 'vertical' then
        code_win_ids = {
            components.previous:get_win_id(),
            components.current:get_win_id(),
            components.previous:get_virtual_line_nr_win_id(),
            components.current:get_virtual_line_nr_win_id(),
        }
    else
        code_win_ids = {
            components.preview:get_win_id(),
            components.preview:get_virtual_line_nr_win_id(),
        }
    end
    if not vim.tbl_contains(code_win_ids, current_win_id) then
        return
    end
    local marks = self.data.diff_change.marks
    if #marks == 0 then
        return self:notify('There are no changes')
    end
    local mark_index = nil
    if direction == 'up' then
        mark_index = navigation.mark_up(code_win_ids, marks)
    end
    if direction == 'down' then
        mark_index = navigation.mark_down(code_win_ids, marks)
    end
    if mark_index then
        scheduler()
        self:notify(string.format('%s/%s Changes', mark_index, #marks))
    end
end

function Preview:mark_up()
    self:navigate_code('up')
end

function Preview:mark_down()
    self:navigate_code('down')
end

function Preview:draw_changes(data)
    local lnum_changes = data.lnum_changes
    local layout_type = self.layout_type or 'horizontal'
    local components = self:get_components()
    local ns_id = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/paint')
    scheduler()
    for i = 1, #lnum_changes do
        scheduler()
        local datum, component, buf = lnum_changes[i], nil, nil
        if layout_type == 'horizontal' then
            component = components.preview
            buf = component:get_buf()
        elseif layout_type == 'vertical' then
            component = components[datum.buftype]
            buf = component:get_buf()
        end
        if not buf or not component then
            logger.error('There are no component or buffer to draw the changes')
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
                vim.api.nvim_win_get_width(component:get_win_id())
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
    local components = self:get_components()
    local line_nr_count = 1
    local virtual_nr_lines = {}
    local hls = {}
    local common_hl = 'LineNr'
    local layout_type = self.layout_type or 'horizontal'
    if layout_type == 'horizontal' then
        local component = components.preview
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
        component:set_virtual_line_nr_lines(virtual_nr_lines, hls)
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
                        component:get_virtual_line_nr_buf(),
                        lnum,
                        defined_sign,
                        render_store.get('preview').sign.priority
                    )
                    scheduler()
                end
            end
        end
    elseif layout_type == 'vertical' then
        local previous_component = components.previous
        local current_component = components.current
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
        current_component:set_virtual_line_nr_lines(virtual_nr_lines, hls)
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
                        current_component:get_virtual_line_nr_buf(),
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
        previous_component:set_virtual_line_nr_lines(virtual_nr_lines, hls)
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
                        previous_component:get_virtual_line_nr_buf(),
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

function Preview:set_mounted(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    self.state.mounted = value
end

function Preview:set_loading(value, force)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    if not self:is_mounted() then
        return self
    end
    for _, component in pairs(self.components) do
        component:set_loading(value, force)
    end
    return self
end

function Preview:set_centered_text(text, force)
    assert(type(text) == 'string', 'type error :: expected string')
    for _, component in pairs(self.components) do
        component:set_centered_text(text, force)
    end
    return self
end

function Preview:set_error(value, force)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    for _, component in pairs(self.components) do
        component:set_error(value, force)
    end
    return self
end

function Preview:get_components()
    return self.components
end

function Preview:get_parent_buf()
    return self.parent_buf
end

function Preview:get_parent_win()
    return self.parent_win
end

function Preview:get_win_ids()
    local win_ids = {}
    for _, component in pairs(self.components) do
        win_ids[#win_ids + 1] = component:get_win_id()
    end
    return win_ids
end

function Preview:get_bufs()
    local bufs = {}
    for _, component in pairs(self.components) do
        bufs[#bufs + 1] = component:get_buf()
    end
    return bufs
end

function Preview:keep_focused()
    local win_ids = self:get_win_ids()
    if #win_ids > 1 then
        local current_win_id = vim.api.nvim_get_current_win()
        if not vim.tbl_contains(win_ids, current_win_id) then
            if vim.tbl_isempty(self.state.win_toggle_queue) then
                self.state.win_toggle_queue = self:get_win_ids()
            end
            vim.api.nvim_set_current_win(table.remove(self.state.win_toggle_queue))
        else
            self.state.win_toggle_queue = self:get_win_ids()
        end
    end
end

function Preview:is_mounted()
    for _, component in pairs(self.components) do
        local win_ids = component:get_win_ids()
        local bufs = component:get_bufs()
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

function Preview:clear()
    for _, component in pairs(self.components) do
        component:clear()
    end
end

function Preview:mount()
    if self:is_mounted() then
        return self
    end
    for _, component in pairs(self.components) do
        component:mount()
    end
    local win_ids = {}
    for _, component in pairs(self.components) do
        win_ids[#win_ids + 1] = component:get_win_id()
        win_ids[#win_ids + 1] = component:get_border_win_id()
        if component:is(CodeComponent) then
            win_ids[#win_ids + 1] = component:get_virtual_line_nr_win_id()
        end
    end
    for _, component in pairs(self.components) do
        component:on(
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
                string.format(':lua _G.package.loaded.vgit.renderer.hide_windows(%s)', vim.inspect(win_ids)),
                { once = true }
            )
        end
    end
    self:set_mounted(true)
    return self
end

function Preview:unmount()
    local components = self:get_components()
    for _, component in pairs(components) do
        component:unmount()
    end
    self:set_mounted(false)
end

function Preview:render()
    error('Preview must implement render method')
end

return Preview
