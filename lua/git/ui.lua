local vim = vim

local constants = {
    group = 'tanvirtin/git.nvim',
    ns_id = vim.api.nvim_create_namespace('tanvirtin/git.nvim'),
    palette = {
        GitDiffWindow = {
            bg = nil,
            fg = '#ffffff',
        },
        GitDiffBorder = {
            bg = nil,
            fg = '#464b59',
        },
        GitDiffAdd = {
            bg = '#4a6317',
            fg = nil
        },
        GitDiffChangeAdd = {
            bg = '#85b329',
            fg = nil
        },
        GitDiffRemove = {
            bg = '#63132f',
            fg = nil,
        },
        GitDiffChangeRemove = {
            bg = '#b82156',
            fg = nil,
        },
        GitHunkWindow = {
            bg = nil,
            fg = '#ffffff',
        },
        GitHunkBorder = {
            bg = nil,
            fg = '#464b59',
        },
        GitHunkAdd = {
            fg = nil,
            bg = '#4a6317',
        },
        GitHunkRemove = {
            fg = nil,
            bg = '#63132f',
        },
        GitHunkSignAdd = {
            fg = '#d7ffaf',
            bg = '#4a6317',
        },
        GitHunkSignRemove = {
            fg = '#e95678',
            bg = '#63132f',
        },
        GitSignAdd = {
            fg = '#d7ffaf',
            bg = nil,
        },
        GitSignChange = {
            fg = '#7AA6DA',
            bg = nil,
        },
        GitSignRemove = {
            fg = '#e95678',
            bg = nil,
        },
    },
}

local function get_initial_state()
    return {
        diff = {
            window = {
                hl_group = 'GitDiffWindow',
                border = {
                    { '╭', 'GitDiffBorder' },
                    { '─', 'GitDiffBorder' },
                    { '╮', 'GitDiffBorder' },
                    { '│', 'GitDiffBorder' },
                    { '╯', 'GitDiffBorder' },
                    { '─', 'GitDiffBorder' },
                    { '╰', 'GitDiffBorder' },
                    { '│', 'GitDiffBorder' },
                }
            },
            types = {
                add = {
                    sign_name = 'GitDiffAdd',
                    hl_group = 'GitDiffAdd',
                    change_hl_group = 'GitDiffChangeAdd'
                },
                remove = {
                    sign_name = 'GitDiffRemove',
                    hl_group = 'GitDiffRemove',
                    change_hl_group = 'GitDiffChangeRemove'
                },
            },
        },
        hunk = {
            types = {
                add = {
                    hl_group = 'GitHunkAdd',
                },
                remove = {
                    hl_group = 'GitHunkRemove',
                },
            },
            window = {
                hl_group = 'GitHunkWindow',
                border = {
                    { '╭', 'GitHunkBorder' },
                    { '─', 'GitHunkBorder' },
                    { '╮', 'GitHunkBorder' },
                    { '│', 'GitHunkBorder' },
                    { '╯', 'GitHunkBorder' },
                    { '─', 'GitHunkBorder' },
                    { '╰', 'GitHunkBorder' },
                    { '│', 'GitHunkBorder' },
                }
            },
            sign = {
                priority = 10,
                types = {
                    add = {
                        name = 'GitHunkSignAdd',
                        hl_group = 'GitHunkSignAdd',
                        text = '+'
                    },
                    remove = {
                        name = 'GitHunkSignRemove',
                        hl_group = 'GitHunkSignRemove',
                        text = '-'
                    },
                },
            }
        },
        sign = {
            priority = 10,
            types = {
                add = {
                    name = 'GitSignAdd',
                    hl_group = 'GitSignAdd',
                    text = '│'
                },
                remove = {
                    name = 'GitSignRemove',
                    hl_group = 'GitSignRemove',
                    text = '│'
                },
                change = {
                    name = 'GitSignChange',
                    hl_group = 'GitSignChange',
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

M.initialize = function()
    for _, action in pairs(state.hunk.types) do
        local hl_group = action.hl_group
        if constants.palette[hl_group] then
            add_highlight(hl_group, constants.palette[hl_group]);
        end
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

    for key, type in pairs(state.hunk.sign.types) do
        local hl_group = state.hunk.sign.types[key].hl_group
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

    for key, _ in pairs(state.diff.types) do
        local sign_name = state.diff.types[key].sign_name
        hl_group = state.diff.types[key].hl_group
        local change_hl_group = state.diff.types[key].change_hl_group
        if constants.palette[hl_group] then
            add_highlight(hl_group, constants.palette[hl_group]);
            add_highlight(change_hl_group, constants.palette[change_hl_group]);
            vim.fn.sign_define(sign_name, {
                text = ' ',
                texthl = hl_group
            })
        end
    end
end

M.tear_down = function()
    M.hide_hunk_signs()
    state = get_initial_state()
end

M.hide_hunk_signs = function()
    vim.fn.sign_unplace(constants.group)
end

M.show_hunk_signs = function(buf, hunks)
    for _, hunk in ipairs(hunks) do
        for i = hunk.start, hunk.finish do
            -- NOTE: lnum cannot be 0, so when i is 0, we make lnum 1 when hunk is of type remove.
            local lnum = (hunk.type == 'remove' and i == 0) and 1 or i
            vim.fn.sign_place(lnum, constants.group, state.sign.types[hunk.type].hl_group, buf, {
                lnum = lnum,
                priority = state.sign.priority,
            })
        end
    end
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

    local width = 40
    local height = #lines

    for _, line in pairs(lines) do
        local line_width = #line
        if line_width > width then
            width = line_width
        end
    end

    for index, line in pairs(lines) do
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            table.insert(added_lines, index)
        elseif first_letter == '-' then
            table.insert(removed_lines, index)
        end
        local line_width = #line
        if line_width <= width then
            for _ = line_width, width do
                line = line .. ' '
            end
        end
        table.insert(trimmed_lines, line:sub(2, #line))
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, true, trimmed_lines)

    highlight_with_ts(buf, filetype)

    for _, lnum in ipairs(added_lines) do
        vim.api.nvim_buf_add_highlight(buf, constants.ns_id, state.hunk.types.add.hl_group, lnum - 1, 0, -1)
        vim.fn.sign_place(lnum, constants.group, state.hunk.sign.types['add'].hl_group, buf, {
            lnum = lnum,
            priority = state.hunk.sign.priority,
        })
    end

    for _, lnum in ipairs(removed_lines) do
        vim.fn.sign_place(lnum, constants.group, state.hunk.sign.types['remove'].hl_group, buf, {
            lnum = lnum,
            priority = state.hunk.sign.priority,
        })
        vim.api.nvim_buf_add_highlight(buf, constants.ns_id, state.hunk.types.remove.hl_group, lnum - 1, 0, -1)
    end

    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    local win_id = vim.api.nvim_open_win(buf, true, {
        relative = 'cursor',
        style = 'minimal',
        height = height,
        width = width + 2,
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
        string.format(':lua require("git").close_preview_window(%s)<CR>', win_id),
        { silent = true }
    )
    for _, current_buf in ipairs(bufs) do
        -- Once split windows are shown, anytime when any other buf currently available enters any window the splits close.
        vim.api.nvim_command(
            string.format(
                'autocmd BufEnter <buffer=%s> lua require("git").close_preview_window(%s)',
                current_buf,
                win_id
            )
        )
    end

    return buf, win_id
end

M.show_diff = function(cwd_lines, origin_lines, lnum_changes, filetype)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local global_width = vim.api.nvim_get_option('columns')
    local global_height = vim.api.nvim_get_option('lines')
    local height = math.ceil(global_height - 4)
    local width = math.ceil(global_width * 0.45)
    local row = math.ceil((global_height - height) / 2 - 1)
    local col = math.ceil((global_width - (width * 2)) / 2)
    local current_line = vim.api.nvim_buf_get_lines(0, lnum - 1, -1, false)[1]

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
        vim.api.nvim_buf_add_highlight(buf, constants.ns_id, state.diff.types[data.type].hl_group, data.lnum - 1, 0, -1)
        vim.fn.sign_place(data.lnum, -1, state.diff.types[data.type].hl_group, buf, {
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
        string.format(':lua require("git").close_preview_window(%s, %s)<CR>', windows.cwd.win_id, windows.cwd.origin_id),
        { silent = true }
    )

    for _, current_buf in ipairs(current_bufs) do
        -- Once split windows are shown, anytime when any other buf currently available enters any window the splits close.
        vim.api.nvim_command(
            string.format(
                'autocmd BufEnter <buffer=%s> lua require("git").close_preview_window(%s, %s)',
                current_buf,
                windows.cwd.win_id,
                windows.origin.win_id
            )
        )
    end

    for index, line in ipairs(cwd_lines) do
        if line == current_line and index >= lnum then
            vim.api.nvim_win_set_cursor(windows.cwd.win_id, { index, 0 })
            break
        end
    end

    return windows.cwd.buf, windows.cwd.win_id, windows.origin.buf, windows.origin.win_id
end

return M
