local utils = require('vgit.utils')
local BlamePreviewPopup = require('vgit.popups.BlamePreviewPopup')
local HistoryPopup = require('vgit.popups.HistoryPopup')
local HunkLensPopup = require('vgit.popups.HunkLensPopup')
local BlamePopup = require('vgit.popups.BlamePopup')
local PreviewPopup = require('vgit.popups.PreviewPopup')
local virtual_text = require('vgit.virtual_text')
local PopupState = require('vgit.PopupState')
local Interface = require('vgit.Interface')
local buffer = require('vgit.buffer')
local sign = require('vgit.sign')
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler

local M = {}

local popup_state = PopupState:new()

M.constants = utils.readonly({
    blame_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/blame'),
    blame_line_id = 1,
})

M.state = Interface:new({
    blame_line = {
        hl = 'VGitLineBlame',
        format = function(blame, git_config)
            local config_author = git_config['user.name']
            local author = blame.author
            if config_author == author then
                author = 'You'
            end
            local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
            local time_format = string.format('%s days ago', utils.round(time))
            local time_divisions = { { 24, 'hours' }, { 60, 'minutes' }, { 60, 'seconds' } }
            local division_counter = 1
            while time < 1 and division_counter ~= #time_divisions do
                local division = time_divisions[division_counter]
                time = time * division[1]
                time_format = string.format('%s %s ago', utils.round(time), division[2])
                division_counter = division_counter + 1
            end
            local commit_message = blame.commit_message
            if not blame.committed then
                author = 'You'
                commit_message = 'Uncommitted changes'
                local info = string.format('%s • %s', author, commit_message)
                return string.format(' %s', info)
            end
            local max_commit_message_length = 255
            if #commit_message > max_commit_message_length then
                commit_message = commit_message:sub(1, max_commit_message_length) .. '...'
            end
            local info = string.format('%s, %s • %s', author, time_format, commit_message)
            return string.format(' %s', info)
        end,
    },
    hunk_sign = {
        priority = 10,
        signs = {
            add = 'VGitSignAdd',
            remove = 'VGitSignRemove',
            change = 'VGitSignChange',
        },
    },
})

M.setup = function(config)
    M.state:assign(config)
    PreviewPopup:setup((config and config.preview) or {})
    HistoryPopup:setup((config and config.history) or {})
    HunkLensPopup:setup((config and config.hunk_lens) or {})
    BlamePopup:setup((config and config.blame) or {})
    BlamePreviewPopup:setup((config and config.blame_preview_popup) or {})
end

M.is_popup_navigatable = function(popup)
    local allowed = {
        PreviewPopup,
        HistoryPopup,
        HunkLensPopup,
    }
    for i = 1, #allowed do
        local T = allowed[i]
        if popup:is(T) then
            return true
        end
    end
    return false
end

M.get_mounted_popup = function()
    return popup_state:get()
end

M.close_windows = function(wins)
    popup_state:set({})
    local existing_wins = vim.api.nvim_list_wins()
    for i = 1, #wins do
        local win = wins[i]
        if vim.api.nvim_win_is_valid(win) and vim.tbl_contains(existing_wins, win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
end

M.show_blame_line = function(buf, blame, lnum, git_config)
    if buffer.is_valid(buf) then
        local virt_text = M.state:get('blame_line').format(blame, git_config)
        if type(virt_text) == 'string' then
            pcall(virtual_text.add, buf, M.constants.blame_namespace, lnum - 1, 0, {
                id = M.constants.blame_line_id,
                virt_text = { { virt_text, M.state:get('blame_line').hl } },
                virt_text_pos = 'eol',
                hl_mode = 'combine',
            })
        end
    end
end

M.hide_blame_line = function(buf)
    if buffer.is_valid(buf) then
        pcall(virtual_text.delete, buf, M.constants.blame_namespace, M.constants.blame_line_id)
    end
end

M.show_hunk_signs = void(function(buf, hunks)
    scheduler()
    if buffer.is_valid(buf) then
        for i = 1, #hunks do
            local hunk = hunks[i]
            for j = hunk.start, hunk.finish do
                sign.place(
                    buf,
                    (hunk.type == 'remove' and j == 0) and 1 or j,
                    M.state:get('hunk_sign').signs[hunk.type],
                    M.state:get('hunk_sign').priority
                )
                scheduler()
            end
            scheduler()
        end
    end
end)

M.hide_hunk_signs = void(function(buf)
    scheduler()
    if buffer.is_valid(buf) then
        sign.unplace(buf)
        scheduler()
    end
end)

M.show_blame = void(function(fetch)
    popup_state:clear()
    local blame_popup = BlamePopup:new()
    popup_state:set(blame_popup)
    blame_popup:mount()
    scheduler()
    local err, data = fetch()
    scheduler()
    blame_popup.err = err
    blame_popup.data = data
    blame_popup:render()
    scheduler()
end)

M.show_blame_preview = void(function(fetch, filetype)
    popup_state:clear()
    local blame_preview_popup = BlamePreviewPopup:new({ filetype = filetype })
    popup_state:set(blame_preview_popup)
    blame_preview_popup:mount()
    blame_preview_popup:set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    blame_preview_popup:set_loading(false)
    scheduler()
    blame_preview_popup.err = err
    blame_preview_popup.data = data
    blame_preview_popup:render()
    scheduler()
end)

M.show_hunk_lens = void(function(fetch, filetype)
    popup_state:clear()
    local current_lnum = vim.api.nvim_win_get_cursor(0)[1]
    local hunk_lens_popup = HunkLensPopup:new({ filetype = filetype })
    popup_state:set(hunk_lens_popup)
    hunk_lens_popup:mount()
    hunk_lens_popup:set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    hunk_lens_popup:set_loading(false)
    scheduler()
    hunk_lens_popup.err = err
    hunk_lens_popup.data = data
    hunk_lens_popup:render()
    scheduler()
    hunk_lens_popup:reposition_cursor(current_lnum)
end)

M.show_preview = void(function(fetch, filetype, layout_type)
    popup_state:clear()
    local current_lnum = vim.api.nvim_win_get_cursor(0)[1]
    local preview_popup = PreviewPopup:new({
        filetype = filetype,
        layout_type = layout_type,
    })
    popup_state:set(preview_popup)
    preview_popup:mount()
    preview_popup:set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    preview_popup:set_loading(false)
    scheduler()
    preview_popup.err = err
    preview_popup.data = data
    preview_popup:render()
    preview_popup:reposition_cursor(current_lnum)
    scheduler()
end)

M.show_history = void(function(fetch, filetype, layout_type)
    popup_state:clear()
    local history_popup = HistoryPopup:new({
        filetype = filetype,
        layout_type = layout_type,
    })
    popup_state:set(history_popup)
    history_popup:mount()
    history_popup:set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    history_popup:set_loading(false)
    scheduler()
    history_popup.err = err
    history_popup.data = data
    history_popup:render()
    scheduler()
end)

M.change_history = void(function(fetch, selected)
    local history_popup = popup_state:get()
    scheduler()
    history_popup:set_loading(true)
    scheduler()
    local err, data = fetch()
    scheduler()
    history_popup:set_loading(false)
    scheduler()
    history_popup.err = err
    history_popup.data = data
    history_popup.selected = selected
    history_popup:render()
    scheduler()
end)

return M
