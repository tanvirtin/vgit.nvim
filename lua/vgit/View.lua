local Object = require('plenary.class')
local navigation = require('vgit.navigation')
local virtual_text = require('vgit.virtual_text')
local sign = require('vgit.sign')
local painter = require('vgit.painter')
local dimensions = require('vgit.dimensions')
local events = require('vgit.events')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')
local Interface = require('vgit.Interface')

local View = Object:extend()

local function calculate_text_center(text, width)
    local rep = math.floor((width / 2) - math.floor(#text / 2))
    return (rep < 0 and 0) or rep
end

local state = Interface:new({
    loading = {
        frame_rate = 60,
        frames = {
            '∙∙∙',
            '●∙∙',
            '∙●∙',
            '∙∙●',
            '∙∙∙',
        },
    },
    error = '✖✖✖',
})

local function create_border_lines(title, content_win_options, border)
    local border_lines = {}
    local topline = nil
    if content_win_options.row > 0 then
        if title ~= '' then
            title = string.format(' %s ', title)
        end
        local left_start = calculate_text_center(title, content_win_options.width)
        topline = string.format(
            '%s%s%s%s%s',
            border[1],
            string.rep(border[2], left_start),
            title,
            string.rep(border[2], content_win_options.width - #title - left_start),
            border[3]
        )
    end
    if topline then
        border_lines[#border_lines + 1] = topline
    end
    local middle_line = string.format(
        '%s%s%s',
        border[4] or '',
        string.rep(' ', content_win_options.width),
        border[8] or ''
    )
    for _ = 1, content_win_options.height do
        border_lines[#border_lines + 1] = middle_line
    end
    border_lines[#border_lines + 1] = string.format(
        '%s%s%s',
        border[7] or '',
        string.rep(border[6], content_win_options.width),
        border[5] or ''
    )
    return border_lines
end

local function create_border(content_buf, title, window_props, border, border_hl)
    local thickness = { top = 1, right = 1, bot = 1, left = 1 }
    local buf = vim.api.nvim_create_buf(true, true)
    buffer.set_lines(buf, create_border_lines(title, window_props, border))
    buffer.assign_options(buf, {
        ['modifiable'] = false,
        ['bufhidden'] = 'wipe',
        ['buflisted'] = false,
    })
    local win_id = vim.api.nvim_open_win(buf, false, {
        relative = 'editor',
        style = 'minimal',
        focusable = false,
        row = window_props.row - thickness.top,
        col = window_props.col - thickness.left,
        width = window_props.width + thickness.left + thickness.right,
        height = window_props.height + thickness.top + thickness.bot,
    })
    vim.api.nvim_win_set_option(win_id, 'cursorbind', false)
    vim.api.nvim_win_set_option(win_id, 'scrollbind', false)
    vim.api.nvim_win_set_option(win_id, 'winhl', string.format('Normal:%s', border_hl))
    events.buf.on(content_buf, 'WinClosed', string.format(':lua require("vgit").ui.close_windows({ %s })', win_id))
    return buf, win_id
end

function View:setup(config)
    state:assign(config)
end

function View:new(options)
    assert(options == nil or type(options) == 'table', 'type error :: expected table or nil')
    options = options or {}
    local height = self:get_min_height()
    local width = self:get_min_width()
    local config = Interface:new({
        filetype = '',
        title = '',
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        border_hl = 'FloatBorder',
        border_focus_hl = 'FloatBorder',
        buf_options = {
            ['modifiable'] = false,
            ['buflisted'] = false,
            ['bufhidden'] = 'wipe',
        },
        win_options = {
            ['wrap'] = false,
            ['number'] = false,
            ['winhl'] = 'Normal:',
            ['cursorline'] = false,
            ['cursorbind'] = false,
            ['scrollbind'] = false,
            ['signcolumn'] = 'auto',
        },
        window_props = {
            style = 'minimal',
            relative = 'editor',
            height = height,
            width = width,
            row = math.ceil((dimensions.global_height() - height) / 2 - 1),
            col = math.ceil((dimensions.global_width() - width) / 2),
            focusable = true,
        },
    })
    config:assign(options)
    return setmetatable({
        state = {
            buf = nil,
            win_id = nil,
            border = {
                buf = nil,
                win_id = nil,
            },
            loading = false,
            error = false,
            mounted = false,
            lines = {},
            cursor_pos = nil,
        },
        config = config,
        anim_id = nil,
    }, View)
end

function View:get_win_id()
    return self.state.win_id
end

function View:get_buf()
    return self.state.buf
end

function View:get_border_buf()
    return self.state.border.buf
end

function View:get_border_win_id()
    return self.state.border.win_id
end

function View:get_buf_option(key)
    return vim.api.nvim_buf_get_option(self.state.buf, key)
end

function View:get_win_option(key)
    return vim.api.nvim_win_get_option(self.state.win_id, key)
end

function View:get_lines()
    return buffer.get_lines(self:get_buf())
end

function View:get_height()
    return vim.api.nvim_win_get_height()
end

function View:get_width()
    return vim.api.nvim_win_get_width()
end

function View:get_min_height()
    return 20
end

function View:get_min_width()
    return 70
end

function View:set_height(value)
    assert(type(value) == 'number', 'type error :: expected number')
    vim.api.nvim_win_set_height(self:get_win_id(), value)
    return self
end

function View:set_width(value)
    assert(type(value) == 'number', 'type error :: expected number')
    vim.api.nvim_win_set_width(self:get_win_id(), value)
    return self
end

function View:set_filetype(filetype)
    assert(type(filetype) == 'string', 'type error :: expected string')
    self.config:set('filetype', filetype)
    local buf = self:get_buf()
    painter.clear_syntax(buf)
    painter.draw_syntax(buf, filetype)
    buffer.set_option(buf, 'syntax', filetype)
    return self
end

function View:set_cursor(row, col)
    assert(type(row) == 'number', 'type error :: expected number')
    assert(type(col) == 'number', 'type error :: expected number')
    navigation.set_cursor(self:get_win_id(), { row, col })
    return self
end

function View:set_buf_option(option, value)
    vim.api.nvim_buf_set_option(self.state.buf, option, value)
    return self
end

function View:set_win_option(option, value)
    vim.api.nvim_win_set_option(self.state.win_id, option, value)
    return self
end

function View:set_title(title)
    assert(type(title) == 'string', 'type error :: expected string')
    buffer.set_lines(
        self.state.border.buf,
        create_border_lines(title, self.state:config('window_props'), self.state:config('border'))
    )
    return self
end

function View:set_lines(lines)
    assert(type(lines) == 'table', 'type error :: expected table')
    self:clear_timers()
    buffer.set_lines(self:get_buf(), lines)
    return self
end

function View:set_centered_animated_text(frame_rate, frames, callback)
    assert(type(frame_rate) == 'number', 'type error :: expected number')
    assert(vim.tbl_islist(frames), 'type error :: expected list table')
    self:clear_timers()
    self:set_centered_text(frames[1], true)
    local frame_count = 1
    self.anim_id = vim.fn.timer_start(frame_rate, function()
        if buffer.is_valid(self:get_buf()) then
            frame_count = frame_count + 1
            local selected_frame = frame_count % #frames
            selected_frame = selected_frame == 0 and 1 or selected_frame
            self:set_centered_text(string.format('%s', frames[selected_frame]), true)
            if callback then
                callback(frame_rate, frames, self.anim_id)
            end
        else
            self:clear_timers()
        end
    end, {
        ['repeat'] = -1,
    })
end

function View:set_loading(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    self:clear_timers()
    if value == self.state.loading then
        return self
    end
    if value then
        self.state.cursor_pos = vim.api.nvim_win_get_cursor(self:get_win_id())
        self.state.loading = value
        local animation_configuration = state:get('loading')
        self:set_centered_animated_text(animation_configuration.frame_rate, animation_configuration.frames)
    else
        painter.draw_syntax(self.state.buf, self.config:get('filetype'))
        self.state.loading = value
        buffer.set_lines(self.state.buf, self.state.lines)
        self:set_win_option('cursorline', self.config:get('win_options').cursorline)
        navigation.set_cursor(self:get_win_id(), self.state.cursor_pos)
        self.state.lines = {}
        self.state.cursor = nil
    end
    return self
end

function View:set_error(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    self:clear_timers()
    if value == self.state.error then
        return self
    end
    if value then
        self.state.error = value
        self:set_centered_text(state:get('error'))
    else
        painter.draw_syntax(self.state.buf, self.config:get('filetype'))
        self.state.error = value
        buffer.set_lines(self.state.buf, self.state.lines)
        self:set_win_option('cursorline', self.config:get('win_options').cursorline)
        self.state.lines = {}
    end
    return self
end

function View:set_centered_text(text, in_animation)
    assert(type(text) == 'string', 'type error :: expected string')
    if not in_animation then
        self:clear_timers()
    end
    painter.clear_syntax(self.state.buf)
    local lines = {}
    local height = vim.api.nvim_win_get_height(self.state.win_id)
    local width = vim.api.nvim_win_get_width(self.state.win_id)
    for _ = 1, height do
        lines[#lines + 1] = ''
    end
    lines[math.ceil(height / 2)] = string.rep(' ', calculate_text_center(text, width)) .. text
    self:set_win_option('cursorline', false)
    self.state.lines = buffer.get_lines(self:get_buf())
    buffer.set_lines(self.state.buf, lines)
    return self
end

function View:on(cmd, handler, options)
    events.buf.on(self:get_buf(), cmd, handler, options)
    return self
end

function View:add_keymap(key, action)
    buffer.add_keymap(self:get_buf(), key, action)
    return self
end

function View:remove_keymap(key)
    buffer.remove_keymap(self:get_buf(), key)
    return self
end

function View:focus()
    vim.api.nvim_set_current_win(self.state.win_id)
    return self
end

function View:is_mounted()
    return self.state.mounted
end

function View:create_table(labels, rows)
    assert(type(labels) == 'table', 'type error :: expected table')
    assert(type(rows) == 'table', 'type error :: expected table')
    self:clear_timers()
    local spacing = 3
    local lines = {}
    local padding = {}
    for i = 1, #rows do
        local items = rows[i]
        assert(#labels == #items, 'number of columns should be the same as number of labels')
        for j = 1, #items do
            local value = items[j]
            if padding[j] then
                padding[j] = math.max(padding[j], #value + spacing)
            else
                padding[j] = spacing + #value + spacing
            end
        end
    end
    local row = string.format('%s', string.rep(' ', spacing))
    for i = 1, #labels do
        local label = labels[i]
        row = string.format('%s%s%s', row, label, string.rep(' ', padding[i] - #label))
    end
    lines[1] = row
    for i = 1, #rows do
        row = string.format('%s', string.rep(' ', spacing))
        local items = rows[i]
        for j = 1, #items do
            local value = items[j]
            row = string.format('%s%s%s', row, value, string.rep(' ', padding[j] - #value))
        end
        lines[#lines + 1] = row
    end
    self:set_lines(lines)
    return self
end

function View:add_indicator(lnum, namespace, hl)
    virtual_text.transpose_text(self:get_buf(), '>', namespace, hl, lnum, 0)
end

function View:clear_timers()
    if self.anim_id then
        vim.fn.timer_stop(self.anim_id)
    end
end

function View:clear()
    sign.unplace(self:get_buf())
    self:clear_timers()
    self:set_loading(false)
    self:set_error(false)
    self:set_lines({})
end

function View:mount()
    if self.state.mounted then
        return self
    end
    local buf_options = self.config:get('buf_options')
    local title = self.config:get('title')
    local border = self.config:get('border')
    local border_hl = self.config:get('border_hl')
    local border_focus_hl = self.config:get('border_focus_hl')
    local window_props = self.config:get('window_props')
    local win_options = self.config:get('win_options')
    local filetype = self.config:get('filetype')
    self.state.buf = vim.api.nvim_create_buf(true, true)
    local buf = self.state.buf
    buffer.assign_options(buf, buf_options)
    if title == '' then
        if border_hl then
            local new_border = {}
            for _, value in pairs(border) do
                if type(value) == 'table' then
                    value[2] = border_hl
                    new_border[#new_border + 1] = value
                else
                    new_border[#new_border + 1] = { value, border_hl }
                end
            end
            window_props.border = new_border
        else
            window_props.border = border
        end
    end
    local win_id = vim.api.nvim_open_win(buf, true, window_props)
    for key, value in pairs(win_options) do
        vim.api.nvim_win_set_option(win_id, key, value)
    end
    self.state.win_id = win_id
    if border and title ~= '' then
        local border_buf, border_win_id = create_border(buf, title, window_props, border, border_focus_hl)
        self.state.border.buf = border_buf
        self.state.border.win_id = border_win_id
        vim.cmd(
            string.format(
                'au BufEnter <buffer=%s> :lua vim.api.nvim_win_set_option(%s, "winhl", "Normal:%s")',
                buf,
                border_win_id,
                border_focus_hl
            )
        )
        vim.cmd(
            string.format(
                'au BufLeave <buffer=%s> :lua vim.api.nvim_win_set_option(%s, "winhl", "Normal:%s")',
                buf,
                border_win_id,
                border_hl
            )
        )
    end
    self:on('BufWinLeave', string.format(':lua require("vgit").ui.close_windows({ %s })', win_id))
    painter.draw_syntax(buf, filetype)
    self.state.mounted = true
    return self
end

function View:unmount()
    self.mounted = false
    local existing_wins = vim.api.nvim_list_wins()
    local win_id = self:get_win_id()
    if vim.api.nvim_win_is_valid(win_id) and vim.tbl_contains(existing_wins, win_id) then
        self:clear()
        pcall(vim.api.nvim_win_close, win_id, true)
    end
end

return View
