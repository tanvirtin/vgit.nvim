local vim = vim

local constants = {
    hunk_signs_group = 'tanvirtin/vgit.nvim/hunk/signs',
    blame_namespace = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/blame'),
    blame_line_id = 1,
    palette = {
        VGitBlame = {
            bg = nil,
            fg = '#b1b1b1',
        },
        VGitDiffWindow = {
            bg = nil,
            fg = '#ffffff',
        },
        VGitDiffBorder = {
            bg = nil,
            fg = '#464b59',
        },
        VGitDiffAddSign = {
            bg = '#3d5213',
            fg = nil,
        },
        VGitDiffRemoveSign = {
            bg = '#4a0f23',
            fg = nil,
        },
        VGitDiffAddText = {
            fg = '#6a8f1f',
            bg = '#3d5213',
        },
        VGitDiffRemoveText = {
            fg = '#a3214c',
            bg = '#4a0f23',
        },
        VGitHunkWindow = {
            bg = nil,
            fg = '#ffffff',
        },
        VGitHunkBorder = {
            bg = nil,
            fg = '#464b59',
        },
        VGitHunkAddSign = {
            bg = '#3d5213',
            fg = nil,
        },
        VGitHunkRemoveSign = {
            bg = '#4a0f23',
            fg = nil,
        },
        VGitHunkAddText = {
            fg = '#6a8f1f',
            bg = '#3d5213',
        },
        VGitHunkRemoveText = {
            fg = '#a3214c',
            bg = '#4a0f23',
        },
        VGitHunkSignAdd = {
            fg = '#d7ffaf',
            bg = '#4a6317',
        },
        VGitHunkSignRemove = {
            fg = '#e95678',
            bg = '#63132f',
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
    },
}

local function round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

local function get_initial_state()
    return {
        blame = {
            hl_group = 'VGitBlame',
            format = function(blame, git_config)
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
        sign = {
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
        }
    }
end

local state = get_initial_state()

local M = {}

local function add_highlight(group, color)
    local style = color.style and 'gui=' .. color.style or 'gui=NONE'
    local fg = color.fg and 'guifg = ' .. color.fg or 'guifg = NONE'
    local bg = color.bg and 'guibg = ' .. color.bg or 'guibg = NONE'
    local sp = color.sp and 'guisp = ' .. color.sp or ''
    vim.api.nvim_command('highlight ' .. group .. ' ' .. style .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp)
end

local function highlight_with_ts(buf, ft)
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

    if has_ts and ft and ft ~= '' then
        local lang = ts_parsers.ft_to_lang(ft);
        if ts_parsers.has_parser(lang) then
            ts_highlight.attach(buf, lang)
            return true
        end
    end
    return false
end

M.setup = function()
    local blame_hl_group = state.blame.hl_group

    if constants.palette[blame_hl_group] then
        add_highlight(blame_hl_group, constants.palette[blame_hl_group]);
    end

    for key, type in pairs(state.sign.types) do
        local hl_group = state.sign.types[key].hl_group
        if constants.palette[hl_group] then
            add_highlight(hl_group, constants.palette[hl_group]);
        end
        vim.fn.sign_define(type.name, {
            text = type.text,
            texthl = type.hl_group
        })
    end

    local hl_group = state.hunk.window.hl_group
    if constants.palette[hl_group] then
        add_highlight(hl_group, constants.palette[hl_group]);
    end
    local hunk_border = state.hunk.window.border
    if type(hunk_border) == 'table' then
        for _, b in ipairs(hunk_border) do
            if type(b) == 'table' then
                hl_group = b[2]
                if hl_group and constants.palette[hl_group] then
                    add_highlight(hl_group, constants.palette[hl_group])
                end
            end
        end
    end

    local diff_border = state.diff.window.border
    if type(diff_border) == 'table' then
        for _, b in ipairs(diff_border) do
            if type(b) == 'table' then
                hl_group = b[2]
                if hl_group and constants.palette[hl_group] then
                    add_highlight(hl_group, constants.palette[hl_group])
                end
            end
        end
    end

    for _, action in pairs(state.hunk.types) do
        local sign_hl_group = action.sign_hl_group
        local text_hl_group = action.text_hl_group
        if constants.palette[sign_hl_group] then
            add_highlight(sign_hl_group, constants.palette[sign_hl_group]);
            add_highlight(text_hl_group, constants.palette[text_hl_group]);
        end
        vim.fn.sign_define(action.name, {
            text = action.text,
            texthl = text_hl_group,
            linehl = sign_hl_group,
        })
    end

    for _, action in pairs(state.diff.types) do
        local name = action.name
        local text = action.text
        local sign_hl_group = action.sign_hl_group
        local text_hl_group = action.text_hl_group
        if constants.palette[sign_hl_group] then
            add_highlight(sign_hl_group, constants.palette[sign_hl_group]);
            add_highlight(text_hl_group, constants.palette[text_hl_group]);
        end
        vim.fn.sign_define(name, {
            text = text,
            texthl = text_hl_group,
            linehl = sign_hl_group,
        })
    end
end

M.tear_down = function()
    state = get_initial_state()
end

M.show_blame = function(buf, blames, git_config)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local blame = blames[lnum]
    vim.api.nvim_buf_set_extmark(buf, constants.blame_namespace, lnum - 1, 0, {
        id = constants.blame_line_id,
        virt_text = { { state.blame.format(blame, git_config), state.blame.hl_group } },
        virt_text_pos = 'eol',
    })
end

M.hide_blame = function(buf)
    vim.api.nvim_buf_del_extmark(buf, constants.blame_namespace, constants.blame_line_id)
end

M.show_hunk_signs = function(buf, hunks)
    local hunk_signs_group = string.format('%s/%s', constants.hunk_signs_group, buf)
    for _, hunk in ipairs(hunks) do
        for i = hunk.start, hunk.finish do
            -- NOTE: lnum cannot be 0, so when i is 0, we make lnum 1 when hunk is of type remove.
            local lnum = (hunk.type == 'remove' and i == 0) and 1 or i
            vim.fn.sign_place(lnum, hunk_signs_group, state.sign.types[hunk.type].hl_group, buf, {
                lnum = lnum,
                priority = state.sign.priority,
            })
        end
    end
end

M.hide_hunk_signs = function(buf)
    local hunk_signs_group = string.format('%s/%s', constants.hunk_signs_group, buf)
    vim.fn.sign_unplace(hunk_signs_group)
end

M.show_hunk = function(hunk, filetype)
    local lines = hunk.diff
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)

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

    vim.api.nvim_buf_set_lines(buf, 0, -1, true, trimmed_lines)

    highlight_with_ts(buf, filetype)

    for _, lnum in ipairs(added_lines) do
        vim.fn.sign_place(lnum, constants.hunk_signs_group, state.hunk.types['add'].sign_hl_group, buf, {
            lnum = lnum,
            priority = state.sign.priority,
        })
    end

    for _, lnum in ipairs(removed_lines) do
        vim.fn.sign_place(lnum, constants.hunk_signs_group, state.hunk.types['remove'].sign_hl_group, buf, {
            lnum = lnum,
            priority = state.sign.priority,
        })
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    local win_id = vim.api.nvim_open_win(buf, true, {
        relative = 'cursor',
        style = 'minimal',
        height = height,
        width = width,
        border = state.hunk.window.border,
        row = 1,
        col = 0,
    })

    vim.api.nvim_win_set_option(win_id, 'winhl', 'Normal:' .. state.hunk.window.hl_group)
    vim.api.nvim_win_set_option(win_id, 'cursorline', true)
    vim.api.nvim_win_set_option(win_id, 'wrap', false)
    vim.api.nvim_win_set_option(win_id, 'signcolumn', 'yes')

    local bufs = vim.api.nvim_list_bufs()
    -- Close on cmd/ctrl - c.
    vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-c>',
        string.format(':lua require("vgit")._close_preview_window(%s)<CR>', win_id),
        { silent = true }
    )
    for _, current_buf in ipairs(bufs) do
        -- Once split windows are shown, anytime when any other buf currently available enters any window the splits close.
        vim.api.nvim_command(
            string.format(
                'autocmd BufEnter <buffer=%s> lua require("vgit")._close_preview_window(%s)',
                current_buf,
                win_id
            )
        )
    end

    return buf, win_id
end

M.show_diff = function(cwd_lines, origin_lines, lnum_changes, filetype)
    local global_width = vim.api.nvim_get_option('columns')
    local global_height = vim.api.nvim_get_option('lines')
    local height = math.ceil(global_height - 4)
    local width = math.ceil(global_width * 0.45)
    local row = math.ceil((global_height - height) / 2 - 1)
    local col = math.ceil((global_width - (width * 2)) / 2)

    local windows = {
        origin = {
            buf = vim.api.nvim_create_buf(false, true),
            lines = origin_lines
        },
        cwd = {
            buf = vim.api.nvim_create_buf(false, true),
            lines = cwd_lines
        }
    }

    for _, window in pairs(windows) do
        vim.api.nvim_buf_set_option(window.buf, 'bufhidden', 'wipe')
        vim.api.nvim_buf_set_option(window.buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(window.buf, 'buflisted', false)
        vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, window.lines)
        highlight_with_ts(window.buf, filetype)
    end

    for _, data in ipairs(lnum_changes) do
        local buf = windows[data.buftype].buf
        vim.fn.sign_place(data.lnum, constants.hunk_signs_group, state.diff.types[data.type].sign_hl_group, buf, {
            lnum = data.lnum,
            priority = state.sign.priority,
        })
    end

    for _, window in pairs(windows) do
        vim.api.nvim_buf_set_option(window.buf, 'modifiable', false)
    end

    windows.cwd.win_id = vim.api.nvim_open_win(windows.cwd.buf, true, {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        border = state.diff.window.border,
        row = row,
        col = col,
    })

    windows.origin.win_id = vim.api.nvim_open_win(windows.origin.buf, false, {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        border = state.diff.window.border,
        row = math.ceil((global_height - height) / 2 - 1),
        col = col + width + 2,
        focusable = false,
    })

    for _, window in pairs(windows) do
        vim.api.nvim_win_set_option(window.win_id, 'winhl', string.format('Normal:%s', state.diff.window.hl_group))
        vim.api.nvim_win_set_option(window.win_id, 'cursorline', true)
        vim.api.nvim_win_set_option(window.win_id, 'wrap', false)
        vim.api.nvim_win_set_option(window.win_id, 'cursorbind', true)
        vim.api.nvim_win_set_option(window.win_id, 'scrollbind', true)
        vim.api.nvim_win_set_option(window.win_id, 'signcolumn', 'yes')
    end

    local current_bufs = vim.api.nvim_list_bufs()
    -- Close on cmd/ctrl - c.
    vim.api.nvim_buf_set_keymap(
        windows.cwd.buf,
        'n',
        '<C-c>',
        string.format(':lua require("vgit")._close_preview_window(%s, %s)<CR>', windows.cwd.win_id, windows.cwd.origin_id),
        { silent = true }
    )

    for _, current_buf in ipairs(current_bufs) do
        -- Once split windows are shown, anytime when any other buf currently available enters any window the splits close.
        vim.api.nvim_command(
            string.format(
                'autocmd BufEnter <buffer=%s> lua require("vgit")._close_preview_window(%s, %s)',
                current_buf,
                windows.cwd.win_id,
                windows.origin.win_id
            )
        )
    end

    return windows.cwd.buf, windows.cwd.win_id, windows.origin.buf, windows.origin.win_id
end

return M
