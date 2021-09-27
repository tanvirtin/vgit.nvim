local dimensions = require('vgit.dimensions')
local Object = require('plenary.class')
local events = require('vgit.events')
local buffer = require('vgit.buffer')

local function sanitize_chars(border)
    for i = 1, 8 do
        border[i] = border[i] or ''
        border[i] = border[i] == '' and ' ' or border[i]
    end
    return border
end

local BorderDecorator = Object:extend()

function BorderDecorator:new(config, window_props, content_buf)
    return setmetatable({
        buf = nil,
        win_id = nil,
        content_buf = content_buf,
        window_props = window_props,
        config = config,
    }, BorderDecorator)
end

function BorderDecorator:make_native(config)
    config = config or self.config
    if config.hl then
        local new_border = {}
        for _, char in pairs(config.chars) do
            if type(char) == 'table' then
                char[2] = config.hl
                new_border[#new_border + 1] = char
            else
                new_border[#new_border + 1] = { char, config.hl }
            end
        end
        return new_border
    end
    return config.chars
end

function BorderDecorator:make_virtual()
    local config = self.config
    local window_props = self.window_props
    local border_lines = {}
    local topline = nil
    if window_props.row > 0 then
        local title = config.title
        if title ~= '' then
            title = string.format(' %s ', title)
        end
        local left_start = dimensions.calculate_text_center(title, window_props.width)
        topline = string.format(
            '%s%s%s%s%s',
            config.chars[1],
            string.rep(config.chars[2], left_start),
            title,
            string.rep(config.chars[2], window_props.width - #title - left_start),
            config.chars[3]
        )
    end
    if topline then
        border_lines[#border_lines + 1] = topline
    end
    local middle_line = string.format('%s%s%s', config.chars[4], string.rep(' ', window_props.width), config.chars[8])
    for _ = 1, window_props.height do
        border_lines[#border_lines + 1] = middle_line
    end
    local footer = config.footer
    if (footer or footer ~= nil) and footer ~= '' then
        footer = string.format(' %s ', footer)
        local left_start = dimensions.calculate_text_center(footer, window_props.width)
        border_lines[#border_lines + 1] = string.format(
            '%s%s%s%s%s',
            config.chars[7],
            string.rep(config.chars[6], left_start),
            footer,
            string.rep(config.chars[6], window_props.width - #footer - left_start),
            config.chars[5]
        )
    else
        border_lines[#border_lines + 1] = string.format(
            '%s%s%s',
            config.chars[7],
            string.rep(config.chars[6], window_props.width),
            config.chars[5]
        )
    end
    return border_lines
end

function BorderDecorator:mount()
    self.config.chars = sanitize_chars(self.config.chars)
    local thickness = {
        top = 1,
        bot = 1,
        left = 1,
        right = 1,
    }
    self.buf = vim.api.nvim_create_buf(true, true)
    buffer.set_lines(self.buf, self:make_virtual())
    buffer.assign_options(self.buf, {
        ['modifiable'] = false,
        ['bufhidden'] = 'wipe',
        ['buflisted'] = false,
    })
    self.win_id = vim.api.nvim_open_win(self.buf, false, {
        style = 'minimal',
        focusable = false,
        relative = self.window_props.relative,
        row = self.window_props.row - thickness.top,
        col = self.window_props.col - thickness.left,
        width = self.window_props.width + thickness.left + thickness.right,
        height = self.window_props.height + thickness.top + thickness.bot,
    })
    vim.api.nvim_win_set_option(self.win_id, 'cursorbind', false)
    vim.api.nvim_win_set_option(self.win_id, 'scrollbind', false)
    vim.api.nvim_win_set_option(self.win_id, 'winhl', string.format('Normal:%s', self.config.focus_hl))
    events.buf.on(
        self.content_buf,
        'WinClosed',
        string.format(':lua _G.package.loaded.vgit.renderer.hide_windows({ %s })', self.win_id),
        { once = true }
    )
    return self
end

function BorderDecorator:get_win_id()
    return self.win_id
end

function BorderDecorator:get_buf()
    return self.buf
end

function BorderDecorator:set_lines(lines)
    buffer.set_lines(self.buf, lines)
end

function BorderDecorator:set_title(title)
    self.config.title = title
    self:set_lines(self:make_virtual())
end

function BorderDecorator:set_footer(footer)
    self.config.footer = footer
    self:set_lines(self:make_virtual())
end

return BorderDecorator
