local buffer = require('vgit.buffer')
local sign = require('vgit.sign')
local virtual_text = require('vgit.virtual_text')

local M = {}

M.draw_syntax = function(buf, filetype)
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
        local lang = ts_parsers.ft_to_lang(filetype)
        if ts_parsers.has_parser(lang) then
            pcall(ts_highlight.attach, buf, lang)
        else
            buffer.set_option(buf, 'syntax', filetype)
        end
    end
end

M.clear_syntax = function(buf)
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

M.draw_changes = function(get_buf, lnum_changes, signs, priority)
    local ns_id = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/paint')
    for i = 1, #lnum_changes do
        local datum = lnum_changes[i]
        local buf = get_buf(datum)
        local type, lnum, word_diff = datum.type, datum.lnum, datum.word_diff
        local defined_sign = signs[type]
        if defined_sign then
            sign.place(buf, lnum, defined_sign, priority)
        end
        if type == 'void' then
            virtual_text.add(buf, ns_id, lnum - 1, 0, {
                id = lnum,
                virt_text = { { string.rep('⣿', vim.api.nvim_win_get_width(0)), 'VGitMuted' } },
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
                    texts[#texts + 1] = {
                        fragment,
                        string.format('VGitViewWord%s', type == 'remove' and 'Remove' or 'Add'),
                    }
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

return M
