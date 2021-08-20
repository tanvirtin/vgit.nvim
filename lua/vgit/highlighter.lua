local Interface = require('vgit.Interface')

local vim = vim

local M = {}

M.state = Interface.new({
    VGitViewWordAdd = {
        bg = '#5d7a22',
        fg = nil,
    },
    VGitViewWordRemove = {
        bg = '#960f3d',
        fg = nil,
    },
    VGitViewSignAdd = {
        bg = '#3d5213',
        fg = nil,
    },
    VGitViewSignRemove = {
        bg = '#4a0f23',
        fg = nil,
    },
    VGitSignAdd = {
        fg = '#d7ffaf',
        bg = nil,
    },
    VGitSignChange = {
        fg = '#7AA6DA',
        bg = nil,
    },
    VGitSignRemove = {
        fg = '#e95678',
        bg = nil,
    },
    VGitIndicator = {
        fg = '#a6e22e',
        bg = nil,
    },
    VGitBorder = {
        fg = '#a1b5b1',
        bg = nil,
    },
    VGitBorderFocus = {
        fg = '#7AA6DA',
        bg = nil,
    },
    VGitLineBlame = {
        bg = nil,
        fg = '#b1b1b1',
    },
    VGitMuted = {
        bg = nil,
        fg = '#303b54',
    },
})

M.setup = function(config)
    M.state:assign((config and config.hls) or config)
    for hl, color in pairs(M.state.data) do
        M.create(hl, color)
    end
end

M.create = function(group, color)
    local gui = color.gui and 'gui = ' .. color.gui or 'gui = NONE'
    local fg = color.fg and 'guifg = ' .. color.fg or 'guifg = NONE'
    local bg = color.bg and 'guibg = ' .. color.bg or 'guibg = NONE'
    local sp = color.sp and 'guisp = ' .. color.sp or ''
    vim.cmd('highlight ' .. group .. ' ' .. gui .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp)
end

M.mark = function(buf, text, ns_id, hl_group, lnum, col_start)
    vim.api.nvim_buf_set_extmark(buf, ns_id, lnum, col_start, {
        id = lnum + 1,
        virt_text = { { text, hl_group } },
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
    })
end

M.create_virtual_line = function(buf, texts, ns_id, lnum)
    vim.api.nvim_buf_set_extmark(buf, ns_id, lnum, 0, {
        id = lnum + 1,
        virt_text = texts,
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
    })
end

return M
