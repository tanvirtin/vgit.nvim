local vim = vim

local constants = {
    group = 'tanvirtin/git.nvim',
    ns_id = vim.api.nvim_create_namespace('tanvirtin/git.nvim'),
    palette = {
        GitDiff = {
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
        GitDiffRemove = {
            bg = '#63132f',
            fg = nil,
        },
        GitHunk = {
            bg = nil,
            fg = '#ffffff',
        },
        GitHunkBorder = {
            bg = nil,
            fg = '#464b59',
        },
        GitHunkAdd = {
            bg = nil,
            fg = '#d7ffaf',
        },
        GitHunkRemove = {
            bg = nil,
            fg = '#e95678',
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
                hl_group = 'GitDiff',
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
                },
                remove = {
                    sign_name = 'GitDiffRemove',
                    hl_group = 'GitDiffRemove',
                },
            }
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
                hl_group = 'GitHunk',
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

local function pad_content(content, padding)
    local pad_top = padding[1] or 0
    local pad_right = padding[2] or 0
    local pad_below = padding[3] or 0
    local pad_left = padding[4] or 0

    local left_padding = string.rep(' ', pad_left)
    local right_padding = string.rep(' ', pad_right)
    for index = 1, #content do
        local line = content[index]
        if line ~= '' then
            content[index] = left_padding .. line .. right_padding
        end
    end

    for _ = 1, pad_top do
        table.insert(content, 1, '')
    end

    for _ = 1, pad_below do
        table.insert(content, '')
    end

    return content
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
        if constants.palette[hl_group] then
            add_highlight(hl_group, constants.palette[hl_group]);
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

M.show_hunk_signs = function(filename, hunks)
    for _, hunk in ipairs(hunks) do
        for i = hunk.start, hunk.finish do
            -- NOTE: lnum cannot be 0, so when i is 0, we make lnum 1 when hunk is of type remove.
            local lnum = (hunk.type == 'remove' and i == 0) and 1 or i
            vim.fn.sign_place(lnum, constants.group, state.sign.types[hunk.type].hl_group, filename, {
                lnum = lnum,
                priority = state.sign.priority,
            })
        end
    end
end

M.show_hunk = function(hunk)
    local padding = { 1, 2, 1, 2 }
    local content = pad_content(vim.deepcopy(hunk.diff), padding)
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'diff')

    for index, line in pairs(content) do
        -- TODO: Remove unnecessary trimming by offsetting the padding instead.
        line = line:gsub('%s+', '')
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            vim.api.nvim_buf_add_highlight(buf, constants.ns_id, state.hunk.types.add.hl_group, index - 1, 0, -1)
        elseif first_letter == '-' then
            vim.api.nvim_buf_add_highlight(buf, constants.ns_id, state.hunk.types.remove.hl_group, index - 1, 0, -1)
        end
    end

    local width = 40
    local height = #content
    for _, line in ipairs(content) do
        local line_width = #line
        if line_width > width then
            width = line_width
        end
    end

    local win_id = vim.api.nvim_open_win(buf, false, {
        relative = 'cursor',
        style = 'minimal',
        height = height,
        width = width,
        border = state.hunk.window.border,
        row = 1,
        col = 0,
    })

    vim.api.nvim_win_set_option(win_id, 'winhl', 'Normal:' .. state.hunk.window.hl_group)
    vim.lsp.util.close_preview_autocmd({ 'BufLeave', 'CursorMoved', 'CursorMovedI' }, win_id)
end

M.show_diff = function(cwd_lines, origin_lines, lnum_changes, filetype)
    local global_width = vim.api.nvim_get_option('columns')
    local global_height = vim.api.nvim_get_option('lines')
    local height = math.ceil(global_height - 4)
    local width = math.ceil(global_width * 0.45)
    local row = math.ceil((global_height - height) / 2 - 1)
    local col = math.ceil((global_width - (width * 2)) / 2)

    local cwd_buf = vim.api.nvim_create_buf(false, true)
    local origin_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_option(cwd_buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(cwd_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(cwd_buf, 'buflisted', false)

    vim.api.nvim_buf_set_option(origin_buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(origin_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(origin_buf, 'buflisted', false)

    vim.api.nvim_buf_set_lines(cwd_buf, 0, -1, false, cwd_lines)
    vim.api.nvim_buf_set_lines(origin_buf, 0, -1, false, origin_lines)

    highlight_with_ts(cwd_buf, filetype)
    highlight_with_ts(origin_buf, filetype)

    -- TODO: Theres one loop in git another loop in ui, is the abstraction worth it?
    for _, lnum in ipairs(lnum_changes.origin.added) do
        vim.api.nvim_buf_add_highlight(origin_buf, constants.ns_id, state.diff.types.add.hl_group, lnum - 1, 0, -1)
        vim.fn.sign_place(lnum, -1, state.diff.types.add.hl_group, origin_buf, {
            lnum = lnum,
            priority = state.sign.priority,
        })
    end
    for _, lnum in ipairs(lnum_changes.origin.removed) do
        vim.api.nvim_buf_add_highlight(origin_buf, constants.ns_id, state.diff.types.remove.hl_group, lnum - 1, 0, -1)
        vim.fn.sign_place(lnum, -1, state.diff.types.remove.hl_group, origin_buf, {
            lnum = lnum,
            priority = state.sign.priority,
        })
    end
    for _, lnum in ipairs(lnum_changes.cwd.added) do
        vim.api.nvim_buf_add_highlight(cwd_buf, constants.ns_id, state.diff.types.add.hl_group, lnum - 1, 0, -1)
        vim.fn.sign_place(lnum, -1, state.diff.types.add.hl_group, cwd_buf, {
            lnum = lnum,
            priority = state.sign.priority,
        })
    end
    for _, lnum in ipairs(lnum_changes.cwd.removed) do
        vim.api.nvim_buf_add_highlight(cwd_buf, constants.ns_id, state.diff.types.remove.hl_group, lnum - 1, 0, -1)
        vim.fn.sign_place(lnum, -1, state.diff.types.remove.hl_group, cwd_buf, {
            lnum = lnum,
            priority = state.sign.priority,
        })
    end

    vim.api.nvim_buf_set_option(origin_buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(cwd_buf, 'modifiable', false)

    local cwd_win_id = vim.api.nvim_open_win(cwd_buf, true, {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        border = state.diff.window.border,
        row = row,
        col = col,
    })

    local origin_win_id = vim.api.nvim_open_win(origin_buf, false, {
        style = 'minimal',
        relative = 'editor',
        width = width,
        height = height,
        border = state.diff.window.border,
        row = math.ceil((global_height - height) / 2 - 1),
        col = col + width + 2,
        focusable = false,
    })

    -- When cursor bind on both buffer windows, moving cursor in one of the window will mimic the position in the other one.
    vim.api.nvim_win_set_option(cwd_win_id, 'winhl', string.format('Normal:%s', state.diff.window.hl_group))
    vim.api.nvim_win_set_option(cwd_win_id, 'cursorline', true)
    vim.api.nvim_win_set_option(cwd_win_id, 'wrap', false)
    vim.api.nvim_win_set_option(cwd_win_id, 'cursorbind', true)
    vim.api.nvim_win_set_option(cwd_win_id, 'signcolumn', 'yes')

    vim.api.nvim_win_set_option(origin_win_id, 'winhl', string.format('Normal:%s', state.diff.window.hl_group))
    vim.api.nvim_win_set_option(origin_win_id, 'cursorline', true)
    vim.api.nvim_win_set_option(origin_win_id, 'wrap', false)
    vim.api.nvim_win_set_option(origin_win_id, 'cursorbind', true)
    vim.api.nvim_win_set_option(origin_win_id, 'signcolumn', 'yes')

    return cwd_buf, cwd_win_id, origin_buf, origin_win_id
end

return M
