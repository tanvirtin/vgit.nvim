local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')
local State = require('vgit.State')

local vim = vim

local View = {}
View.__index = View

local function colorize(buf, filetype)
    if not filetype or filetype == '' then
        return
    end
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
        local lang = ts_parsers.ft_to_lang(filetype);
        if ts_parsers.has_parser(lang) then
            pcall(ts_highlight.attach, buf, lang)
        else
            buffer.set_option(buf, 'syntax', filetype)
        end
    end
end

local function uncolorize(buf)
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

local function calculate_text_center(text, width)
    local rep = math.floor((width / 2) - math.floor(#text / 2))
    return (rep < 0 and 0) or rep
end

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
    buffer.add_autocmd(
        content_buf,
        'WinClosed',
        string.format('_run_submodule_command("ui", "close_windows", { %s })', win_id)
    )
    return buf, win_id
end

local function global_width()
    return vim.o.columns
end

local function global_height()
    return vim.o.lines
end

local function new(options)
    assert(options == nil or type(options) == 'table', 'type error :: expected table or nil')
    options = options or {}
    local height = 10
    local width = 70
    local config = State.new({
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
            row = math.ceil((global_height() - height) / 2 - 1),
            col = math.ceil((global_width() - width) / 2),
        },
    })
    config:assign(options)
    return setmetatable({
        state = {
            buf = vim.api.nvim_create_buf(true, true),
            win_id = nil,
            border = {
                buf = nil,
                win_id = nil,
            },
            loading = false,
            error = false,
            rendered = false,
            lines = {},
        },
        config = config
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

function View:set_buf_option(option, value)
    vim.api.nvim_buf_set_option(self.state.buf, option, value)
    return self
end

function View:set_win_option(option, value)
    vim.api.nvim_win_set_option(self.state.win_id, option, value)
    return self
end

function View:set_title(title)
    buffer.set_lines(
        self.state.border.buf,
        create_border_lines(title, self.state:config('window_props'), self.state:config('border'))
    )
    return self
end

function View:set_lines(lines)
    buffer.set_lines(self:get_buf(), lines)
    return self
end

function View:get_lines()
    return buffer.get_lines(self:get_buf())
end

function View:set_loading(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    if value == self.state.loading then
        return self
    end
    if value then
        self.state.loading = value
        self:set_centered_text('•••')
    else
        colorize(self.state.buf, self.config:get('filetype'))
        self.state.loading = value
        buffer.set_lines(self.state.buf, self.state.lines)
        self:set_win_option('cursorline', self.config:get('win_options').cursorline)
        self.state.lines = {}
    end
    return self
end

function View:set_error(value)
    assert(type(value) == 'boolean', 'type error :: expected boolean')
    if value == self.state.error then
        return self
    end
    if value then
        self.state.error = value
        self:set_centered_text('✖✖✖')
    else
        colorize(self.state.buf, self.config:get('filetype'))
        self.state.error = value
        buffer.set_lines(self.state.buf, self.state.lines)
        self:set_win_option('cursorline', self.config:get('win_options').cursorline)
        self.state.lines = {}
    end
    return self
end

function View:set_centered_text(text)
    assert(type(text) == 'string', 'type error :: expected string')
    uncolorize(self.state.buf)
    local lines = {}
    local height = vim.api.nvim_win_get_height(self.state.win_id)
    local width = vim.api.nvim_win_get_width(self.state.win_id)
    for _ = 1, height do
        lines[#lines + 1] = ''
    end
    lines[math.floor(height / 2)] = string.rep(' ', calculate_text_center(text, width)) .. text
    self:set_win_option('cursorline', false)
    self.state.lines = buffer.get_lines(self:get_buf())
    buffer.set_lines(self.state.buf, lines)
    return self
end

function View:add_autocmd(cmd, action, options)
    local buf = self:get_buf()
    local persist = (options and options.persist) or false
    local override = (options and options.override) or false
    local nested = (options and options.nested) or false
    vim.cmd(
        string.format(
            'au%s %s <buffer=%s> %s %s :lua require("vgit").%s',
            override and '!' or '',
            cmd,
            buf,
            nested and '++nested' or '',
            persist and '' or '++once',
            action
        )
    )
    return self
end

function View:add_keymap(key, action)
    buffer.add_keymap(self:get_buf(), key, action)
    return self
end

function View:focus()
    vim.api.nvim_set_current_win(self.state.win_id)
    return self
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
    if filetype == self.config:get('filetype') then
        return
    end
    self.config:set('filetype', filetype)
    local buf = self:get_buf()
    uncolorize(buf)
    colorize(buf, filetype)
    buffer.set_option(buf, 'syntax', filetype)
end

function View:render()
    if self.state.rendered then
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
    local buf = self:get_buf()
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
    self.state.buf = buf
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
    self:add_autocmd('BufWinLeave', string.format('_run_submodule_command("ui", "close_windows", { %s })', win_id))
    colorize(buf, filetype)
    self.state.rendered = true
    return self
end

return {
    new = new,
    __object = View,
}
