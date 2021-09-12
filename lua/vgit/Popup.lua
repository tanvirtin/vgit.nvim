local Object = require('plenary.class')
local render_store = require('vgit.stores.render_store')
local navigation = require('vgit.navigation')
local virtual_text = require('vgit.virtual_text')
local sign = require('vgit.sign')
local events = require('vgit.events')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')
local Interface = require('vgit.Interface')

local function calculate_text_center(text, width)
    local rep = math.floor((width / 2) - math.floor(#text / 2))
    return (rep < 0 and 0) or rep
end

local function create_border_lines(title, content_win_options, border, footer)
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
    if footer or footer ~= nil then
        footer = string.format(' %s ', footer)
        local left_start = calculate_text_center(footer, content_win_options.width)
        border_lines[#border_lines + 1] = string.format(
            '%s%s%s%s%s',
            border[7] or '',
            string.rep(border[6] or '', left_start),
            footer,
            string.rep(border[6] or '', content_win_options.width - #footer - left_start),
            border[5] or ''
        )
    else
        border_lines[#border_lines + 1] = string.format(
            '%s%s%s',
            border[7] or '',
            string.rep(border[6], content_win_options.width),
            border[5] or ''
        )
    end
    return border_lines
end

local function clean_border(border)
    for i = 1, 8 do
        border[i] = border[i] or ''
        border[i] = border[i] == '' and ' ' or border[i]
    end
    return border
end

local function create_border(content_buf, title, window_props, border, border_hl)
    border = clean_border(border)
    local thickness = {
        top = 1,
        bot = 1,
        left = 1,
        right = 1,
    }
    local buf = vim.api.nvim_create_buf(false, true)
    buffer.set_lines(buf, create_border_lines('' or title, window_props, border))
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
    events.buf.on(
        content_buf,
        'WinClosed',
        string.format(':lua require("vgit").renderer.hide_windows({ %s })', win_id),
        { once = true }
    )
    return buf, win_id
end

local function create_virtual_line_nr(content_buf, window_props, width)
    local buf = vim.api.nvim_create_buf(false, true)
    buffer.assign_options(buf, {
        ['modifiable'] = false,
        ['bufhidden'] = 'wipe',
        ['buflisted'] = false,
    })
    local win_id = vim.api.nvim_open_win(buf, false, {
        relative = 'editor',
        style = 'minimal',
        row = window_props.row,
        col = window_props.col,
        width = width,
        height = window_props.height,
        focusable = false,
    })
    vim.api.nvim_win_set_option(win_id, 'cursorbind', true)
    vim.api.nvim_win_set_option(win_id, 'scrollbind', true)
    vim.api.nvim_win_set_option(win_id, 'winhl', 'Normal:')
    events.buf.on(
        content_buf,
        'WinClosed',
        string.format(':lua require("vgit").renderer.hide_windows({ %s })', win_id),
        { once = true }
    )
    return buf, win_id
end

local Popup = Object:extend()

Popup.state = Interface:new({
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

function Popup:setup(config)
    Popup.state:assign(config)
end

function Popup:new(options)
    assert(options == nil or type(options) == 'table', 'type error :: expected table or nil')
    options = options or {}
    local height = self:get_min_height()
    local width = self:get_min_width()
    local config = Interface:new({
        filetype = '',
        border = {
            enabled = false,
            title = '',
            virtual = true,
            hl = 'FloatBorder',
            focus_hl = 'FloatBorder',
            chars = { '', '', '', '', '', '', '', '' },
        },
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
            row = 1,
            col = 0,
            focusable = true,
        },
        virtual_line_nr = {
            enabled = false,
            width = render_store.get('preview').virtual_line_nr_width,
        },
        static = false,
    })
    config:assign(options)
    return setmetatable({
        state = {
            buf = nil,
            win_id = nil,
            ns_id = nil,
            border = {
                buf = nil,
                win_id = nil,
            },
            virtual_line_nr = {
                buf = nil,
                win_id = nil,
                ns_id = nil,
            },
            loading = false,
            error = false,
            mounted = false,
            cache = {
                lines = {},
                cursor = nil,
            },
            paint_count = 0,
        },
        config = config,
        anim_id = nil,
    }, Popup)
end

function Popup:has_custom_borders()
    return self:get_border_win_id() ~= nil
end

function Popup:has_virtual_line_nr()
    return self.config:get('virtual_line_nr').enabled
end

function Popup:is_static()
    return self.config:get('static')
end

function Popup:has_lines()
    return self:get_paint_count() > 0
end

function Popup:get_paint_count()
    return self.state.paint_count
end

function Popup:get_win_ids()
    return { self.state.win_id, self.state.border.win_id, self.state.virtual_line_nr.win_id }
end

function Popup:get_bufs()
    return { self.state.buf, self.state.border.buf, self.state.virtual_line_nr.buf }
end

function Popup:get_win_id()
    return self.state.win_id
end

function Popup:get_buf()
    return self.state.buf
end

function Popup:get_ns_id()
    return self.state.ns_id
end

function Popup:get_border_buf()
    return self.state.border.buf
end

function Popup:get_border_win_id()
    return self.state.border.win_id
end

function Popup:get_virtual_line_nr_buf()
    return self.state.virtual_line_nr.buf
end

function Popup:get_virtual_line_nr_win_id()
    return self.state.virtual_line_nr.win_id
end

function Popup:get_virtual_line_nr_ns_id()
    return self.state.virtual_line_nr.ns_id
end

function Popup:get_buf_option(key)
    return buffer.get_option(self:get_win_id(), key)
end

function Popup:get_win_option(key)
    return vim.api.nvim_win_get_option(self:get_win_id(), key)
end

function Popup:get_lines()
    return buffer.get_lines(self:get_buf())
end

function Popup:get_height()
    return vim.api.nvim_win_get_height(self:get_win_id())
end

function Popup:get_width()
    return vim.api.nvim_win_get_width(self:get_win_id())
end

function Popup:get_min_height()
    return 20
end

function Popup:get_min_width()
    return 70
end

function Popup:get_cached_lines()
    return self.state.cache.lines
end

function Popup:get_cached_cursor()
    return self.state.cache.cursor
end

function Popup:get_loading()
    return self.state.loading
end

function Popup:get_error()
    return self.state.error
end

function Popup:is_mounted()
    return self.state.mounted
end

function Popup:set_ns_id(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.ns_id = value
    return self
end

function Popup:set_buf(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.buf = value
    return self
end

function Popup:set_win_id(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.win_id = value
    return self
end

function Popup:set_cached_lines(value)
    assert(vim.tbl_islist(value), 'type error :: expected list table')
    self.state.cache.lines = value
    return self
end

function Popup:set_cached_cursor(value)
    assert(vim.tbl_islist(value), 'type error :: expected list table')
    self.state.cache.cursor = value
    return self
end

function Popup:set_virtual_line_nr_buf(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.virtual_line_nr.buf = value
end

function Popup:set_virtual_line_nr_win_id(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.virtual_line_nr.win_id = value
end

function Popup:set_virtual_line_nr_ns_id(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.virtual_line_nr.ns_id = value
end

function Popup:set_border_buf(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.border.buf = value
end

function Popup:set_border_win_id(value)
    assert(type(value) == 'number', 'type error :: expected number')
    self.state.border.win_id = value
end

function Popup:set_height(value)
    assert(type(value) == 'number', 'type error :: expected number')
    vim.api.nvim_win_set_height(self:get_win_id(), value)
    return self
end

function Popup:set_width(value)
    assert(type(value) == 'number', 'type error :: expected number')
    vim.api.nvim_win_set_width(self:get_win_id(), value)
    return self
end

function Popup:add_syntax_highlights()
    local filetype = self.config:get('filetype')
    if not filetype or filetype == '' then
        return
    end
    local buf = self:get_buf()
    local has_ts = false
    local ts_highlight = nil
    local ts_parsers = nil
    if not has_ts then
        has_ts, _ = pcall(require, 'nvim-treesitter')
        if has_ts then
            _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
            _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
        end
    end
    if has_ts and filetype and filetype ~= '' then
        local lang = ts_parsers.ft_to_lang(filetype)
        if ts_parsers.has_parser(lang) then
            pcall(ts_highlight.attach, buf, lang)
        else
            buffer.set_option(buf, 'syntax', filetype)
        end
    end
end

function Popup:clear_syntax_highlights()
    local buf = self:get_buf()
    local has_ts = false
    if not has_ts then
        has_ts, _ = pcall(require, 'nvim-treesitter')
    end
    if has_ts then
        local active_buf = vim.treesitter.highlighter.active[buf]
        if active_buf then
            active_buf:destroy()
        else
            buffer.set_option(buf, 'syntax', '')
        end
    end
end

function Popup:increment_paint_count()
    self.state.paint_count = self.state.paint_count + 1
    return self
end

function Popup:set_filetype(filetype)
    assert(type(filetype) == 'string', 'type error :: expected string')
    self.config:set('filetype', filetype)
    local buf = self:get_buf()
    self:clear_syntax_highlights()
    self:add_syntax_highlights()
    buffer.set_option(buf, 'syntax', filetype)
    return self
end

function Popup:set_cursor(row, col)
    assert(type(row) == 'number', 'type error :: expected number')
    assert(type(col) == 'number', 'type error :: expected number')
    navigation.set_cursor(self:get_win_id(), { row, col })
    if self:has_virtual_line_nr() then
        navigation.set_cursor(self:get_virtual_line_nr_win_id(), { row, col })
    end
    return self
end

function Popup:set_buf_option(option, value)
    vim.api.nvim_buf_set_option(self:get_buf(), option, value)
    return self
end

function Popup:set_win_option(option, value)
    vim.api.nvim_win_set_option(self:get_win_id(), option, value)
    return self
end

function Popup:set_title(title)
    if not self.config:get('border').enabled then
        return
    end
    assert(self:get_border_win_id(), 'No border exists')
    assert(type(title) == 'string', 'type error :: expected string')
    buffer.set_lines(
        self:get_border_buf(),
        create_border_lines(title, self.config:get('window_props'), self.config:get('border').chars)
    )
    return self
end

function Popup:set_footer(footer)
    if not self.config:get('border').enabled then
        return
    end
    assert(self:get_border_win_id(), 'No border exists')
    assert(type(footer) == 'string' or footer == nil, 'type error :: expected string or nil')
    buffer.set_lines(
        self:get_border_buf(),
        create_border_lines(
            self.config:get('border').title,
            self.config:get('window_props'),
            self.config:get('border').chars,
            footer
        )
    )
    return self
end

function Popup:set_lines(lines, force)
    if self:is_static() and self:has_lines() and not force then
        return self
    end
    assert(type(lines) == 'table', 'type error :: expected table')
    self:increment_paint_count()
    self:clear_timers()
    buffer.set_lines(self:get_buf(), lines)
    return self
end

function Popup:set_virtual_line_nr_lines(lines, hls)
    assert(type(lines) == 'table', 'type error :: expected table')
    assert(self:has_virtual_line_nr(), 'cannot set virtual number lines -- virtual number is disabled')
    vim.api.nvim_win_close(self:get_virtual_line_nr_win_id(), true)
    local buf, win_id = create_virtual_line_nr(
        self:get_buf(),
        self.config:get('window_props'),
        self.config:get('virtual_line_nr').width
    )
    local ns_id = vim.api.nvim_create_namespace(string.format('tanvirtin/vgit.nvim/virtual_line_nr/%s', win_id))
    self:set_virtual_line_nr_buf(buf)
    self:set_virtual_line_nr_win_id(win_id)
    self:set_virtual_line_nr_ns_id(ns_id)
    buffer.set_lines(buf, lines)
    for i = 1, #hls do
        vim.api.nvim_buf_add_highlight(buf, -1, hls[i], i - 1, 0, -1)
    end
    return self
end

function Popup:set_centered_animated_text(frame_rate, frames, force, callback)
    assert(type(frame_rate) == 'number', 'type error :: expected number')
    assert(vim.tbl_islist(frames), 'type error :: expected list table')
    self:clear_timers()
    self:set_centered_text(frames[1], true, force)
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

function Popup:set_loading(value, force)
    if self:is_static() and self:has_lines() and not force then
        return self
    end
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    self:clear_timers()
    if value == self:get_loading() then
        return self
    end
    if value then
        self:set_cached_cursor(vim.api.nvim_win_get_cursor(self:get_win_id()))
        self.state.loading = value
        local animation_configuration = Popup.state:get('loading')
        self:set_centered_animated_text(animation_configuration.frame_rate, animation_configuration.frames, force)
    else
        self:add_syntax_highlights()
        self.state.loading = value
        buffer.set_lines(self:get_buf(), self:get_cached_lines())
        self:set_win_option('cursorline', self.config:get('win_options').cursorline)
        navigation.set_cursor(self:get_win_id(), self:get_cached_cursor())
        self:set_cached_lines({})
        self.state.cursor = nil
    end
    return self
end

function Popup:set_error(value, force)
    if self:is_static() and self:has_lines() and not force then
        return self
    end
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    self:clear_timers()
    if value == self:get_error() then
        return self
    end
    if value then
        self.state.error = value
        self:set_centered_text(Popup.state:get('error'))
    else
        self:add_syntax_highlights()
        self.state.error = value
        buffer.set_lines(self:get_buf(), self:get_cached_lines())
        self:set_win_option('cursorline', self.config:get('win_options').cursorline)
        self:set_cached_lines({})
    end
    return self
end

function Popup:set_centered_text(text, in_animation, force)
    if self:is_static() and self:has_lines() and not force then
        return self
    end
    assert(type(text) == 'string', 'type error :: expected string')
    if not in_animation then
        self:clear_timers()
    end
    self:clear_syntax_highlights()
    local lines = {}
    local win_id = self:get_win_id()
    local height = vim.api.nvim_win_get_height(win_id)
    local width = vim.api.nvim_win_get_width(win_id)
    for _ = 1, height do
        lines[#lines + 1] = ''
    end
    lines[math.ceil(height / 2)] = string.rep(' ', calculate_text_center(text, width)) .. text
    self:set_win_option('cursorline', false)
    self:set_cached_lines(buffer.get_lines(self:get_buf()))
    buffer.set_lines(self:get_buf(), lines)
    if self:has_virtual_line_nr() then
        buffer.set_lines(self:get_virtual_line_nr_buf(), {})
    end
    return self
end

function Popup:set_mounted(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    self.state.mounted = value
end

function Popup:on(cmd, handler, options)
    events.buf.on(self:get_buf(), cmd, handler, options)
    return self
end

function Popup:add_keymap(key, action)
    buffer.add_keymap(self:get_buf(), key, action)
    return self
end

function Popup:remove_keymap(key)
    buffer.remove_keymap(self:get_buf(), key)
    return self
end

function Popup:transpose_text(text, row, col)
    assert(vim.tbl_islist(text), 'type error :: expected list table')
    assert(#text == 2, 'invalid number of text entries')
    assert(type(row) == 'number', 'type error :: expected number')
    assert(type(col) == 'number', 'type error :: expected number')
    virtual_text.transpose_text(self:get_buf(), text[1], self:get_ns_id(), text[2], row, col)
end

function Popup:transpose_line(texts, row)
    assert(vim.tbl_islist(texts), 'type error :: expected list table')
    assert(type(row) == 'number', 'type error :: expected number')
    virtual_text.transpose_line(self:get_buf(), texts, self:get_ns_id(), row)
end

function Popup:focus()
    vim.api.nvim_set_current_win(self:get_win_id())
    return self
end

function Popup:clear_timers()
    if self.anim_id then
        vim.fn.timer_stop(self.anim_id)
    end
end

function Popup:clear(force)
    sign.unplace(self:get_buf())
    virtual_text.clear(self:get_buf(), self:get_ns_id())
    if self:is_static() and not force then
        self:clear_timers()
        return
    end
    self:set_loading(false)
    self:set_error(false)
    self:set_lines({}, force)
    return self
end

function Popup:mount()
    if self:is_mounted() then
        return self
    end
    local buf_options = self.config:get('buf_options')
    local border = self.config:get('border')
    local border_enabled = border.enabled
    local window_props = self.config:get('window_props')
    local win_options = self.config:get('win_options')
    self:set_buf(vim.api.nvim_create_buf(false, true))
    local buf = self:get_buf()
    buffer.assign_options(buf, buf_options)
    if border_enabled and not border.virtual then
        if border.hl then
            local new_border = {}
            for _, char in pairs(border.chars) do
                if type(char) == 'table' then
                    char[2] = border.hl
                    new_border[#new_border + 1] = char
                else
                    new_border[#new_border + 1] = { char, border.hl }
                end
            end
            window_props.border = new_border
        else
            window_props.border = border.chars
        end
    else
        window_props.border = nil
    end
    local win_ids = {}
    local virtual_line_nr_width = self.config:get('virtual_line_nr').width
    local virtual_line_nr_enabled = self.config:get('virtual_line_nr').enabled
    if virtual_line_nr_enabled then
        local virtual_line_nr_buf, virtual_line_nr_win_id = create_virtual_line_nr(
            buf,
            window_props,
            virtual_line_nr_width
        )
        self:set_virtual_line_nr_buf(virtual_line_nr_buf)
        self:set_virtual_line_nr_win_id(virtual_line_nr_win_id)
        window_props.width = window_props.width - virtual_line_nr_width
        window_props.col = window_props.col + virtual_line_nr_width
        win_ids[#win_ids + 1] = virtual_line_nr_win_id
    end
    local win_id = vim.api.nvim_open_win(buf, true, window_props)
    for key, value in pairs(win_options) do
        vim.api.nvim_win_set_option(win_id, key, value)
    end
    self:set_win_id(win_id)
    self:set_ns_id(vim.api.nvim_create_namespace(string.format('tanvirtin/vgit.nvim/%s/%s', buf, win_id)))
    if virtual_line_nr_enabled then
        window_props.width = window_props.width + virtual_line_nr_width
        window_props.col = window_props.col - virtual_line_nr_width
    end
    if border_enabled and border.virtual then
        local border_buf, border_win_id = create_border(buf, border.title, window_props, border.chars, border.focus_hl)
        self:set_border_buf(border_buf)
        self:set_border_win_id(border_win_id)
        self:on(
            'BufEnter',
            string.format(':lua vim.api.nvim_win_set_option(%s, "winhl", "Normal:%s")', border_win_id, border.focus_hl)
        )
        self:on(
            'WinLeave',
            string.format(':lua vim.api.nvim_win_set_option(%s, "winhl", "Normal:%s")', border_win_id, border.hl)
        )
        win_ids[#win_ids + 1] = border_win_id
    end
    win_ids[#win_ids + 1] = win_id
    self:on('BufWinLeave', string.format(':lua require("vgit").renderer.hide_windows(%s)', win_ids))
    self:add_syntax_highlights()
    self:set_mounted(true)
    return self
end

function Popup:unmount()
    self:set_mounted(false)
    local win_id = self:get_win_id()
    local border_win_id = self:get_border_win_id()
    local virtual_win_id = self:get_virtual_line_nr_win_id()
    if vim.api.nvim_win_is_valid(win_id) then
        self:clear()
        pcall(vim.api.nvim_win_close, win_id, true)
    end
    if vim.api.nvim_win_is_valid(border_win_id) then
        pcall(vim.api.nvim_win_close, border_win_id, true)
    end
    if virtual_win_id and vim.api.nvim_win_is_valid(virtual_win_id) then
        pcall(vim.api.nvim_win_close, virtual_win_id, true)
    end
    return self
end

return Popup
