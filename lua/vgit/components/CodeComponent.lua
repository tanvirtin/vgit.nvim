local Component = require('vgit.Component')
local buffer = require('vgit.buffer')
local BorderDecorator = require('vgit.decorators.BorderDecorator')
local VirtualLineNrDecorator = require('vgit.decorators.VirtualLineNrDecorator')

local CodeComponent = Component:extend()

function CodeComponent:new(options)
    return setmetatable(Component:new(options), CodeComponent)
end

function CodeComponent:mount()
    if self:is_mounted() then
        return self
    end
    local buf_options = self.config:get('buf_options')
    local border_config = self.config:get('border')
    local window_props = self.config:get('window_props')
    local win_options = self.config:get('win_options')
    self:set_buf(vim.api.nvim_create_buf(false, true))
    local buf = self:get_buf()
    buffer.assign_options(buf, buf_options)
    local win_ids = {}
    local virtual_line_nr_config = self.config:get('virtual_line_nr')
    if virtual_line_nr_config.enabled then
        self:set_virtual_line_nr(VirtualLineNrDecorator:new(virtual_line_nr_config, window_props, buf))
        local virtual_line_nr = self:get_virtual_line_nr()
        virtual_line_nr:mount()
        window_props.width = window_props.width - virtual_line_nr_config.width
        window_props.col = window_props.col + virtual_line_nr_config.width
        win_ids[#win_ids + 1] = virtual_line_nr:get_win_id()
    end
    if self:is_hover() then
        window_props.border = BorderDecorator:make_native(border_config)
    end
    local win_id = vim.api.nvim_open_win(buf, true, window_props)
    for key, value in pairs(win_options) do
        vim.api.nvim_win_set_option(win_id, key, value)
    end
    self:set_win_id(win_id)
    self:set_ns_id(vim.api.nvim_create_namespace(string.format('tanvirtin/vgit.nvim/%s/%s', buf, win_id)))
    if virtual_line_nr_config then
        window_props.width = window_props.width + virtual_line_nr_config.width
        window_props.col = window_props.col - virtual_line_nr_config.width
    end
    if border_config.enabled and not self:is_hover() then
        self:set_border(BorderDecorator:new(border_config, window_props, buf))
        local border = self:get_border()
        border:mount()
        self:on(
            'BufEnter',
            string.format(
                ':lua vim.api.nvim_win_set_option(%s, "winhl", "Normal:%s")',
                border:get_win_id(),
                border_config.focus_hl
            )
        )
        self:on(
            'WinLeave',
            string.format(
                ':lua vim.api.nvim_win_set_option(%s, "winhl", "Normal:%s")',
                border:get_win_id(),
                border_config.hl
            )
        )
        win_ids[#win_ids + 1] = border:get_win_id()
    end
    win_ids[#win_ids + 1] = win_id
    self:on('BufWinLeave', string.format(':lua require("vgit").renderer.hide_windows(%s)', win_ids))
    self:add_syntax_highlights()
    self:set_mounted(true)
    return self
end

function CodeComponent:unmount()
    self:set_mounted(false)
    local win_id = self:get_win_id()
    if vim.api.nvim_win_is_valid(win_id) then
        self:clear()
        pcall(vim.api.nvim_win_close, win_id, true)
    end
    if self:has_border() then
        local border_win_id = self:get_border_win_id()
        if vim.api.nvim_win_is_valid(border_win_id) then
            pcall(vim.api.nvim_win_close, border_win_id, true)
        end
    end
    if self:has_virtual_line_nr() then
        local virtual_line_nr_win_id = self:get_virtual_line_nr_win_id()
        if virtual_line_nr_win_id and vim.api.nvim_win_is_valid(virtual_line_nr_win_id) then
            pcall(vim.api.nvim_win_close, virtual_line_nr_win_id, true)
        end
    end
    return self
end

return CodeComponent
