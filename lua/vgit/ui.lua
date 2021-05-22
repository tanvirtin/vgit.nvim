local configurer = require('vgit.configurer')
local popup = require('vgit.popup')
local highlighter = require('vgit.highlighter')

local vim = vim

local function get_initial_state()
    return {
        blame = {
            hl_group = 'VGitBlame',
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
        diff = {
            window = {
                hl_group = 'VGitDiffWindow',
                border = {
                    { '╭', 'VGitDiffBorder' },
                    { '─', 'VGitDiffBorder' },
                    { '╮', 'VGitDiffBorder' },
                    { '│', 'VGitDiffBorder' },
                    { '╯', 'VGitDiffBorder' },
                    { '─', 'VGitDiffBorder' },
                    { '╰', 'VGitDiffBorder' },
                    { '│', 'VGitDiffBorder' },
                }
            },
            priority = 10,
            types = {
                add = {
                    name = 'VGitDiffAddSign',
                    sign_hl_group = 'VGitDiffAddSign',
                    text_hl_group = 'VGitDiffAddText',
                    text = '+'
                },
                remove = {
                    name = 'VGitDiffRemoveSign',
                    sign_hl_group = 'VGitDiffRemoveSign',
                    text_hl_group = 'VGitDiffRemoveText',
                    text = '-'
                },
            },
        },
        hunk = {
            priority = 10,
            types = {
                add = {
                    name = 'VGitHunkAddSign',
                    sign_hl_group = 'VGitHunkAddSign',
                    text_hl_group = 'VGitHunkAddText',
                    text = '+'
                },
                remove = {
                    name = 'VGitHunkRemoveSign',
                    sign_hl_group = 'VGitHunkRemoveSign',
                    text_hl_group = 'VGitHunkRemoveText',
                    text = '-'
                },
            },
            window = {
                hl_group = 'VGitHunkWindow',
                border = {
                    { '', 'VGitHunkBorder' },
                    { '─', 'VGitHunkBorder' },
                    { '', 'VGitHunkBorder' },
                    { '', 'VGitHunkBorder' },
                    { '', 'VGitHunkBorder' },
                    { '─', 'VGitHunkBorder' },
                    { '', 'VGitHunkBorder' },
                    { '', 'VGitHunkBorder' },
                }
            },
        },
        hunk_sign = {
            priority = 10,
            types = {
                add = {
                    name = 'VGitSignAdd',
                    hl_group = 'VGitSignAdd',
                    text = '│'
                },
                remove = {
                    name = 'VGitSignRemove',
                    hl_group = 'VGitSignRemove',
                    text = '│'
                },
                change = {
                    name = 'VGitSignChange',
                    hl_group = 'VGitSignChange',
                    text = '│'
                },
            },
        },
        logs = {
            indicator = {
                hl_group = 'VGitLogsIndicator'
            },
            window = {
                hl_group = 'VGitLogsWindow',
                border = {
                    { '╭', 'VGitLogsBorder' },
                    { '─', 'VGitLogsBorder' },
                    { '╮', 'VGitLogsBorder' },
                    { '│', 'VGitLogsBorder' },
                    { '╯', 'VGitLogsBorder' },
                    { '─', 'VGitLogsBorder' },
                    { '╰', 'VGitLogsBorder' },
                    { '│', 'VGitLogsBorder' },
                }
            },
        }
    }
end

local M = {}

M.constants = {
    hunk_signs_group = 'tanvirtin/vgit.nvim/hunk/signs',
    logs_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/logs'),
    blame_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/blame'),
    blame_line_id = 1,
}

M.state = get_initial_state()

M.setup = function(config)
    M.state = configurer.assign(M.state, config)
    highlighter.define(M.state.blame.hl_group);
    for _, type in pairs(M.state.hunk_sign.types) do
        highlighter.define(type.hl_group)
        vim.fn.sign_define(type.name, {
            text = type.text,
            texthl = type.hl_group
        })
    end
    highlighter.define(M.state.hunk.window.hl_group)
    local hunk_border = M.state.hunk.window.border
    if type(hunk_border) == 'table' then
        for _, b in ipairs(hunk_border) do
            if type(b) == 'table' then
                highlighter.define(b[2])
            end
        end
    end
    local diff_border = M.state.diff.window.border
    if type(diff_border) == 'table' then
        for _, b in ipairs(diff_border) do
            if type(b) == 'table' then
                highlighter.define(b[2])
            end
        end
    end
    highlighter.define(M.state.logs.indicator.hl_group)
    local logs_border = M.state.logs.window.border
    if type(logs_border) == 'table' then
        for _, b in ipairs(logs_border) do
            if type(b) == 'table' then
                highlighter.define(b[2])
            end
        end
    end
    for _, action in pairs(M.state.hunk.types) do
        local sign_hl_group = action.sign_hl_group
        local text_hl_group = action.text_hl_group
        highlighter.define(sign_hl_group)
        highlighter.define(text_hl_group)
        vim.fn.sign_define(action.name, {
            text = action.text,
            texthl = text_hl_group,
            linehl = sign_hl_group,
        })
    end
    for _, action in pairs(M.state.diff.types) do
        local name = action.name
        local text = action.text
        local sign_hl_group = action.sign_hl_group
        local text_hl_group = action.text_hl_group
        highlighter.define(sign_hl_group)
        highlighter.define(text_hl_group)
        vim.fn.sign_define(name, {
            text = text,
            texthl = text_hl_group,
            linehl = sign_hl_group,
        })
    end
end

M.show_blame = function(buf, blames, git_config)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local blame = blames[lnum]
    local virt_text = M.state.blame.format(blame, git_config)
    if type(virt_text) == 'string' then
        vim.api.nvim_buf_set_extmark(buf, M.constants.blame_namespace, lnum - 1, 0, {
            id = M.constants.blame_line_id,
            virt_text = { { virt_text, M.state.blame.hl_group } },
            virt_text_pos = 'eol',
        })
    end
end

M.hide_blame = function(buf)
    vim.api.nvim_buf_del_extmark(buf, M.constants.blame_namespace, M.constants.blame_line_id)
end

M.show_hunk_signs = function(buf, hunks)
    local hunk_signs_group = string.format('%s/%s', M.constants.hunk_signs_group, buf)
    for _, hunk in ipairs(hunks) do
        for i = hunk.start, hunk.finish do
            local lnum = (hunk.type == 'remove' and i == 0) and 1 or i
            vim.fn.sign_place(lnum, hunk_signs_group, M.state.hunk_sign.types[hunk.type].hl_group, buf, {
                lnum = lnum,
                priority = M.state.hunk_sign.priority,
            })
        end
    end
end

M.hide_hunk_signs = function(buf)
    local hunk_signs_group = string.format('%s/%s', M.constants.hunk_signs_group, buf)
    vim.fn.sign_unplace(hunk_signs_group)
end

M.show_hunk = function(hunk, filetype)
    local lines = hunk.diff
    local trimmed_lines = {}
    local added_lines = {}
    local removed_lines = {}
    local height = #lines
    local width = vim.api.nvim_get_option('columns')
    for index, line in pairs(lines) do
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            table.insert(added_lines, index)
        elseif first_letter == '-' then
            table.insert(removed_lines, index)
        end
        table.insert(trimmed_lines, line:sub(2, #line))
    end
    local windows = {
        hunk = popup.create({
            filetype = filetype,
            lines = trimmed_lines,
            buf_options = {
                ['modifiable'] = false,
                ['bufhidden'] = 'delete',
                ['buftype'] = 'nofile',
                ['buflisted'] = false,
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', M.state.hunk.window.hl_group),
                ['cursorline'] = true,
                ['wrap'] = false,
                ['signcolumn'] = 'yes',
            },
            window_props = {
                style = 'minimal',
                relative = 'cursor',
                width = width,
                height = height,
                border = M.state.hunk.window.border,
                row = 1,
                col = 0,
            },
        })
    }
    popup.close_mappings({ '<esc>', '<C-c>', ':' }, windows)
    popup.connect_closing_windows(windows)
    for _, lnum in ipairs(added_lines) do
        vim.fn.sign_place(
            lnum,
            M.constants.hunk_signs_group,
            M.state.hunk.types['add'].sign_hl_group,
            windows.hunk.buf,
            {
                lnum = lnum,
                priority = M.state.hunk_sign.priority,
            }
        )
    end
    for _, lnum in ipairs(removed_lines) do
        vim.fn.sign_place(
            lnum,
            M.constants.hunk_signs_group,
            M.state.hunk.types['remove'].sign_hl_group,
            windows.hunk.buf,
            {
                lnum = lnum,
                priority = M.state.hunk_sign.priority,
            }
        )
    end
end

M.show_diff = function(cwd_lines, origin_lines, lnum_changes, filetype)
    local global_width = vim.api.nvim_get_option('columns')
    local global_height = vim.api.nvim_get_option('lines')
    local height = math.ceil(global_height)
    local width = math.ceil(global_width * 0.48)
    local col = math.ceil((global_width - (width * 2)) / 2) - 2
    local windows = {
        origin = popup.create({
            filetype = filetype,
            lines = origin_lines,
            buf_options = {
                ['modifiable'] = false,
                ['bufhidden'] = 'delete',
                ['buftype'] = 'nofile',
                ['buflisted'] = false,
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', M.state.diff.window.hl_group),
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
                border = M.state.diff.window.border,
                row = 0,
                col = col,
            },
        }),
        cwd = popup.create({
            lines = cwd_lines,
            filetype = filetype,
            buf_options = {
                ['modifiable'] = false,
                ['bufhidden'] = 'delete',
                ['buftype'] = 'nofile',
                ['buflisted'] = false,
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', M.state.diff.window.hl_group),
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
                border = M.state.diff.window.border,
                row = 0,
                col = col + width + 2,
            }
        }),
    }
    popup.close_mappings({ '<esc>', '<C-c>', ':' }, windows)
    popup.connect_closing_windows(windows)
    for _, data in ipairs(lnum_changes) do
        local buf = windows[data.buftype].buf
        vim.fn.sign_place(data.lnum, M.constants.hunk_signs_group, M.state.diff.types[data.type].sign_hl_group, buf, {
            lnum = data.lnum,
            priority = M.state.diff.priority,
        })
    end
end

M.change_history = function(
    origin_win_id,
    cwd_win_id,
    origin_buf,
    cwd_buf,
    logs_buf,
    cwd_lines,
    origin_lines,
    selected_log,
    lnum_changes
)
    vim.api.nvim_win_set_cursor(origin_win_id, { 1, 0 })
    vim.api.nvim_win_set_cursor(cwd_win_id, { 1, 0 })
    local windows = {
        origin = { buf = origin_buf },
        cwd = { buf = cwd_buf }
    }
    vim.fn.sign_unplace(M.constants.hunk_signs_group)
    for _, data in ipairs(lnum_changes) do
        local buf = windows[data.buftype].buf
        vim.fn.sign_place(data.lnum, M.constants.hunk_signs_group, M.state.diff.types[data.type].sign_hl_group, buf, {
            lnum = data.lnum,
            priority = M.state.diff.priority,
        })
    end
    local logs_lines = vim.api.nvim_buf_get_lines(logs_buf, 0, -1, false)
    for index, line in ipairs(logs_lines) do
        if index == selected_log then
            logs_lines[index] = string.format('>%s', line:sub(2, #line))
        else
            logs_lines[index] = string.format(' %s', line:sub(2, #line))
        end
    end
    popup.set_lines(logs_buf, logs_lines)
    popup.set_lines(cwd_buf, cwd_lines)
    popup.set_lines(origin_buf, origin_lines)
    local lnum = selected_log - 1
    vim.highlight.range(logs_buf, M.constants.logs_namespace, M.state.logs.indicator.hl_group, { lnum, 0 }, { lnum, 1 })
end

M.show_history = function(cwd_lines, origin_lines, logs, lnum_changes, filetype)
    local current_buf = vim.api.nvim_get_current_buf()
    local global_width = vim.api.nvim_get_option('columns')
    local global_height = vim.api.nvim_get_option('lines')
    local height = math.ceil(global_height - 12)
    local width = math.ceil(global_width * 0.48)
    local logs_width = width * 2 + 2
    local col = math.ceil((global_width - (width * 2)) / 2) - 2
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
    local logs_lines = {}
    for _, row in ipairs(rows) do
        local line = ''
        for index, item in ipairs(row) do
           line = line .. item .. string.rep(' ',  table_title_space[index] - #item)
           if index ~= #table_title_space then
               line = line
           end
        end
        table.insert(logs_lines, line)
    end
    local windows = {
        origin = popup.create({
            filetype = filetype,
            lines = origin_lines,
            buf_options = {
                ['modifiable'] = false,
                ['buftype'] = 'nofile',
                ['buflisted'] = false,
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', M.state.diff.window.hl_group),
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
                border = M.state.diff.window.border,
                row = 0,
                col = col,
            },
        }),
        cwd = popup.create({
            lines = cwd_lines,
            filetype = filetype,
            buf_options = {
                ['modifiable'] = false,
                ['buftype'] = 'nofile',
                ['buflisted'] = false,
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', M.state.diff.window.hl_group),
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
                border = M.state.diff.window.border,
                row = 0,
                col = col + width + 2,
            }
        }),
        logs =  popup.create({
            lines = logs_lines,
            buf_options = {
                ['modifiable'] = false,
                ['buftype'] = 'nofile',
                ['buflisted'] = false,
            },
            win_options = {
                ['winhl'] = string.format('Normal:%s', M.state.logs.window.hl_group),
                ['cursorline'] = true,
                ['cursorbind'] = false,
                ['scrollbind'] = false,
                ['wrap'] = false,
            },
            window_props = {
                style = 'minimal',
                relative = 'editor',
                width = logs_width,
                height = 7,
                border = M.state.logs.window.border,
                row = height + 3,
                col = col,
            }
        }),
    }
    popup.close_mappings({ '<esc>', '<C-c>', ':' }, windows)
    popup.connect_closing_windows(windows)
    popup.add_keymap(
        windows.logs.buf,
        '<enter>',
        string.format(
            '_change_history(%s, %s, %s, %s, %s, %s)',
            current_buf,
            windows.origin.win_id,
            windows.cwd.win_id,
            windows.origin.buf,
            windows.cwd.buf,
            windows.logs.buf
        )
    )
    for _, data in ipairs(lnum_changes) do
        local buf = windows[data.buftype].buf
        vim.fn.sign_place(
            data.lnum,
            M.constants.hunk_signs_group,
            M.state.diff.types[data.type].sign_hl_group,
            buf,
            {
                lnum = data.lnum,
                priority = M.state.diff.priority,
            }
        )
    end
    vim.highlight.range(
        windows.logs.buf,
        M.constants.logs_namespace,
        M.state.logs.indicator.hl_group,
        { 0, 0 }, { 0, 1 }
    )
end

return M
