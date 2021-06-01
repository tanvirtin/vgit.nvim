local State = require('vgit.State')
local buffer = require('vgit.buffer')
local highlighter = require('vgit.highlighter')
local localization = require('vgit.localization')
local View = require('vgit.View')
local Widget = require('vgit.Widget')
local a = require('plenary.async_lib.async')
local t = localization.translate
local async_void = a.async_void
local await = a.await
local scheduler = a.scheduler

local vim = vim

local M = {}

M.constants = {
    hunk_signs_group = 'tanvirtin/vgit.nvim/hunk/signs',
    history_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/history'),
    blame_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/blame'),
    blame_line_id = 1,
}

M.state = State.new({
    blame = {
        hl = 'VGitBlame',
        format = function(blame, git_config)
            local round = function(x)
                return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
            end
            local config_author = git_config['user.name']
            local author = blame.author
            if config_author == author then
                author = 'You'
            end
            local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
            local time_format = string.format('%s days ago', round(time))
            local time_divisions = { { 24, 'hours' }, { 60, 'minutes' }, { 60, 'seconds' } }
            local division_counter = 1
            while time < 1 and division_counter ~= #time_divisions do
                local division = time_divisions[division_counter]
                time = time * division[1]
               time_format = string.format('%s %s ago', round(time), division[2])
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
        end
    },
    preview = {
        priority = 10,
        current_window = {
            title = t('preview/current'),
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitDiffCurrentBorder',
        },
        previous_window = {
            title = t('preview/previous'),
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitDiffPreviousBorder',
        },
        signs = {
            add = {
                name = 'VGitDiffAddSign',
                sign_hl = 'VGitDiffAddSign',
                text_hl = 'VGitDiffAddText',
                text = '+'
            },
            remove = {
                name = 'VGitDiffRemoveSign',
                sign_hl = 'VGitDiffRemoveSign',
                text_hl = 'VGitDiffRemoveText',
                text = '-'
            },
        },
    },
    history = {
        indicator = {
            hl = 'VGitHistoryIndicator'
        },
        current_window = {
            title = t('history/current'),
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitHistoryCurrentBorder',
        },
        previous_window = {
            title = t('history/previous'),
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitHistoryPreviousBorder',
        },
        history_window = {
            title = t('history/history'),
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitHistoryBorder',
        },
    },
    hunk = {
        priority = 10,
        window = {
            border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
            border_hl = 'VGitHunkBorder',
        },
        signs = {
            add = {
                name = 'VGitHunkAddSign',
                sign_hl = 'VGitHunkAddSign',
                text_hl = 'VGitHunkAddText',
                text = '+'
            },
            remove = {
                name = 'VGitHunkRemoveSign',
                sign_hl = 'VGitHunkRemoveSign',
                text_hl = 'VGitHunkRemoveText',
                text = '-'
            },
        },
    },
    hunk_sign = {
        priority = 10,
        signs = {
            add = {
                name = 'VGitSignAdd',
                hl = 'VGitSignAdd',
                text = '│'
            },
            remove = {
                name = 'VGitSignRemove',
                hl = 'VGitSignRemove',
                text = '│'
            },
            change = {
                name = 'VGitSignChange',
                hl = 'VGitSignChange',
                text = '│'
            },
        },
    },
})

M.close_windows = function(wins)
    local existing_wins = vim.api.nvim_list_wins()
    for _, win in ipairs(wins) do
        if vim.api.nvim_win_is_valid(win) and vim.tbl_contains(existing_wins, win) then
            local buf = vim.api.nvim_win_get_buf(win)
            pcall(vim.api.nvim_win_close, win, true)
            if buffer.is_valid(buf) then
                pcall(vim.api.nvim_buf_delete, buf)
            end
        end
    end
end

M.apply_highlights = function()
  for _, type in pairs(M.state:get('hunk_sign').signs) do
        highlighter.define(type.hl)
        vim.fn.sign_define(type.name, {
            text = type.text,
            texthl = type.hl
        })
    end
    for _, action in pairs(M.state:get('hunk').signs) do
        local sign_hl = action.sign_hl
        local text_hl = action.text_hl
        highlighter.define(sign_hl)
        highlighter.define(text_hl)
        vim.fn.sign_define(action.name, {
            text = action.text,
            texthl = text_hl,
            linehl = sign_hl,
        })
    end
    for _, action in pairs(M.state:get('preview').signs) do
        local name = action.name
        local text = action.text
        local sign_hl = action.sign_hl
        local text_hl = action.text_hl
        highlighter.define(sign_hl)
        highlighter.define(text_hl)
        vim.fn.sign_define(name, {
            text = text,
            texthl = text_hl,
            linehl = sign_hl,
        })
    end
    highlighter.define(M.state:get('blame').hl)
    highlighter.define(M.state:get('history').indicator.hl)
    highlighter.define(M.state:get('preview').current_window.border_hl)
    highlighter.define(M.state:get('preview').previous_window.border_hl)
    highlighter.define(M.state:get('history').previous_window.border_hl)
    highlighter.define(M.state:get('history').current_window.border_hl)
    highlighter.define(M.state:get('history').history_window.border_hl)
    highlighter.define(M.state:get('hunk').window.border_hl)
end

M.setup = function(config)
    M.state:assign(config)
    M.apply_highlights()
end

M.show_blame = function(buf, blame, lnum, git_config)
    if buffer.is_valid(buf) then
        local virt_text = M.state:get('blame').format(blame, git_config)
        if type(virt_text) == 'string' then
            pcall(vim.api.nvim_buf_set_extmark, buf, M.constants.blame_namespace, lnum - 1, 0, {
                id = M.constants.blame_line_id,
                virt_text = { { virt_text, M.state:get('blame').hl } },
                virt_text_pos = 'eol',
            })
        end
    end
end

M.hide_blame = function(buf)
    if buffer.is_valid(buf) then
        pcall(vim.api.nvim_buf_del_extmark, buf, M.constants.blame_namespace, M.constants.blame_line_id)
    end
end

M.show_hunk_signs = function(buf, hunks)
    if buffer.is_valid(buf) then
        local hunk_signs_group = string.format('%s/%s', M.constants.hunk_signs_group, buf)
        for _, hunk in ipairs(hunks) do
            for i = hunk.start, hunk.finish do
                local lnum = (hunk.type == 'remove' and i == 0) and 1 or i
                vim.fn.sign_place(lnum, hunk_signs_group, M.state:get('hunk_sign').signs[hunk.type].hl, buf, {
                    lnum = lnum,
                    priority = M.state:get('hunk_sign').priority,
                })
            end
        end
    end
end

M.hide_hunk_signs = function(buf)
    if buffer.is_valid(buf) then
        local hunk_signs_group = string.format('%s/%s', M.constants.hunk_signs_group, buf)
        vim.fn.sign_unplace(hunk_signs_group)
    end
end

M.show_hunk = function(hunk, filetype)
    local lines = hunk.diff
    local trimmed_lines = {}
    local added_lines = {}
    local removed_lines = {}
    for index, line in pairs(lines) do
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            table.insert(added_lines, index)
        elseif first_letter == '-' then
            table.insert(removed_lines, index)
        end
        table.insert(trimmed_lines, line:sub(2, #line))
    end
    local view = View.new({
        filetype = filetype,
        lines = trimmed_lines,
        border = M.state:get('hunk').window.border,
        border_hl = M.state:get('hunk').window.border_hl,
        win_options = { ['cursorline'] = true},
        window_props = {
            style = 'minimal',
            relative = 'cursor',
            height = #lines,
            width = vim.api.nvim_get_option('columns'),
            row = 0,
            col = 0,
        },
    })
    local widget = Widget.new({ view })
    widget:render()
    view:set_lines(trimmed_lines)
    for _, lnum in ipairs(added_lines) do
        vim.fn.sign_place(
            lnum,
            M.constants.hunk_signs_group,
            M.state:get('hunk').signs['add'].sign_hl,
            view:get_buf(),
            {
                lnum = lnum,
                priority = M.state:get('hunk_sign').priority,
            }
        )
    end
    for _, lnum in ipairs(removed_lines) do
        vim.fn.sign_place(
            lnum,
            M.constants.hunk_signs_group,
            M.state:get('hunk').signs['remove'].sign_hl,
            view:get_buf(),
            {
                lnum = lnum,
                priority = M.state:get('hunk_sign').priority,
            }
        )
    end
end

M.show_preview = async_void(function(fetch, filetype)
    local height = math.ceil(View.global_height() - 4)
    local width = math.ceil(View.global_width() * 0.485)
    local col = math.ceil((View.global_width() - (width * 2)) / 2) - 1
    local views = {
        previous = View.new({
            filetype = filetype,
            title = M.state:get('preview').previous_window.title,
            border = M.state:get('preview').previous_window.border,
            border_hl = M.state:get('preview').previous_window.border_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col,
            },
        }),
        current = View.new({
            filetype = filetype,
            title = M.state:get('preview').current_window.title,
            border = M.state:get('preview').current_window.border,
            border_hl = M.state:get('preview').current_window.border_hl,
            win_options = {
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['cursorline'] = true,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col + width + 2,
            },
        })
    }
    local widget = Widget.new(views)
        :render()
        :set_loading(true)
    local err, data = await(fetch())
    await(scheduler())
    widget:set_loading(false)
    if not err then
        views.previous:set_lines(data.previous_lines)
        views.current:set_lines(data.current_lines)
        for _, datum in ipairs(data.lnum_changes) do
            vim.fn.sign_place(
                datum.lnum, M.constants.hunk_signs_group,
                M.state:get('preview').signs[datum.type].sign_hl,
                (views[datum.buftype]):get_buf(),
                {
                    lnum = datum.lnum,
                    priority = M.state:get('preview').priority,
                }
            )
        end
    else
        widget:set_error(true)
    end
end)

M.change_history = function(
    wins_to_update,
    bufs_to_update,
    selected_log,
    current_lines,
    previous_lines,
    lnum_changes
)
    local bufs = {
        current = bufs_to_update[1],
        previous = bufs_to_update[2],
        history = bufs_to_update[3],
    }
    for _, win in pairs(wins_to_update) do
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
    end
    vim.fn.sign_unplace(M.constants.hunk_signs_group)
    for _, data in ipairs(lnum_changes) do
        local buf = bufs[data.buftype]
        vim.fn.sign_place(
            data.lnum,
            M.constants.hunk_signs_group,
            M.state:get('preview').signs[data.type].sign_hl,
            buf,
            {
                lnum = data.lnum,
                priority = M.state:get('preview').priority,
            }
        )
    end
    local history_lines = buffer.get_lines(bufs.history)
    for index, line in ipairs(history_lines) do
        if index == selected_log then
            history_lines[index] = string.format('>%s', line:sub(2, #line))
        else
            history_lines[index] = string.format(' %s', line:sub(2, #line))
        end
    end
    buffer.set_lines(bufs.history, history_lines)
    buffer.set_lines(bufs.current, current_lines)
    buffer.set_lines(bufs.previous, previous_lines)
    local lnum = selected_log - 1
    vim.highlight.range(
        bufs.history,
        M.constants.history_namespace,
        M.state:get('history').indicator.hl,
        { lnum, 0 },
        { lnum, 1 }
    )
end

M.show_history = function(current_lines, previous_lines, logs, lnum_changes, filetype)
    local parent_buf = vim.api.nvim_get_current_buf()
    local height = math.ceil(View.global_height() - 13)
    local width = math.ceil(View.global_width() * 0.485)
    local col = math.ceil((View.global_width() - (width * 2)) / 2) - 1
    local padding_right = 2
    local table_title_space = { padding_right, padding_right, padding_right, padding_right, 0 }
    local rows = {}
    for index, log in ipairs(logs) do
        local row = {
            index - 1 == 0 and string.format('>  HEAD~%s', index - 1) or string.format('   HEAD~%s', index - 1),
            log.author_name or '',
            log.commit_hash or '',
            log.summary or '', (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp))) or ''
        }
        for i, item in ipairs(row) do
            if #item + 1 > table_title_space[i] then
                table_title_space[i] = #item + padding_right
            end
        end
        table.insert(rows, row)
    end
    local history_lines = {}
    for _, row in ipairs(rows) do
        local line = ''
        for index, item in ipairs(row) do
           line = line .. item .. string.rep(' ',  table_title_space[index] - #item)
           if index ~= #table_title_space then
               line = line
           end
        end
        table.insert(history_lines, line)
    end
    local views = {
        previous = View.new({
            filetype = filetype,
            lines = previous_lines,
            border = M.state:get('history').previous_window.border,
            border_hl = M.state:get('history').previous_window.border_hl,
            title = M.state:get('history').previous_window.title,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['signcolumn'] = 'yes',
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col,
            },
        }),
        current = View.new({
            lines = current_lines,
            filetype = filetype,
            title = M.state:get('history').current_window.title,
            border = M.state:get('history').current_window.border,
            border_hl = M.state:get('history').current_window.border_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['wrap'] = false,
                ['cursorbind'] = true,
                ['scrollbind'] = true,
                ['signcolumn'] = 'yes',
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width,
                height = height,
                row = 1,
                col = col + width + 2,
            },
        }),
        history = View.new({
            lines = history_lines,
            title = M.state:get('history').history_window.title,
            border = M.state:get('history').history_window.border,
            border_hl = M.state:get('history').history_window.border_hl,
            buf_options = {
                ['modifiable'] = false,
                ['buflisted'] = false,
                ['bufhidden'] = 'wipe',
            },
            win_options = {
                ['winhl'] = 'Normal:',
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = width * 2 + 2,
                height = 7,
                row = height + 3,
                col = col,
            },
        }),
    }
    local widget = Widget.new(views)
    widget:render()
    views.history:add_keymap('<enter>', string.format(
        '_change_history(%s, %s, %s)',
        parent_buf,
        vim.inspect({
            views.current:get_win_id(),
            views.previous:get_win_id()
        }),
        vim.inspect({
            views.current:get_buf(),
            views.previous:get_buf(),
            views.history:get_buf(),
        })
    ))
    for _, data in ipairs(lnum_changes) do
        local view = views[data.buftype]
        vim.fn.sign_place(
            data.lnum,
            M.constants.hunk_signs_group,
            M.state:get('preview').signs[data.type].sign_hl,
            view:get_buf(),
            {
                lnum = data.lnum,
                priority = M.state:get('preview').priority,
            }
        )
    end
    vim.highlight.range(
        views.history:get_buf(),
        M.constants.history_namespace,
        M.state:get('history').indicator.hl,
        { 0, 0 }, { 0, 1 }
    )
end

return M
