local fs = require('git.fs')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local conf = require('telescope.config').values

local M = {}

local constants = {
    palette = {
        GitDiff = {
            bg = nil,
            fg = '#ffffff',
        },
        GitDiffBorder = {
            bg = nil,
            fg = '#464b59',
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
        GitAdd = {
            bg = '#d7ffaf',
            fg = nil,
        },
        GitChange = {
            bg = '#7AA6DA',
            fg = nil,
        },
        GitRemove = {
            bg = '#e95678',
            fg = nil,
        },
    },
}

local state = {
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
        ns_id = 'git',
        priority = 10,
        types = {
            add = {
                hl_group = 'GitAdd',
                text = ' '
            },
            remove = {
                hl_group = 'GitRemove',
                text = ' '
            },
            change = {
                hl_group = 'GitChange',
                text = ' '
            },
        },
    }
}

local function add_highlight(group, color)
    local style = color.style and 'gui=' .. color.style or 'gui=NONE'
    local fg = color.fg and 'guifg = ' .. color.fg or 'guifg = NONE'
    local bg = color.bg and 'guibg = ' .. color.bg or 'guibg = NONE'
    local sp = color.sp and 'guisp = ' .. color.sp or ''
    vim.api.nvim_command('highlight ' .. group .. ' ' .. style .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp)
end

local function pad_content(content, padding)
    pad_top = padding[1] or 0
    pad_right = padding[2] or 0
    pad_below = padding[3] or 0
    pad_left = padding[4] or 0

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

local function highlight_with_ts(bufnr, ft)
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
            ts_highlight.attach(bufnr, lang)
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
        vim.fn.sign_define(type.hl_group, {
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
                local hl_group = b[2]
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
                local hl_group = b[2]
                if hl_group and constants.palette[hl_group] then
                    add_highlight(hl_group, constants.palette[hl_group])
                end
            end
        end
    end
end

M.tear_down = function()
    M.hide_signs(function()
        state = nil
    end)
end

M.hide_signs = function(callback)
    vim.schedule(function()
        vim.fn.sign_unplace(state.sign.ns_id)
        if type(callback) == 'function' then
            callback()
        end
    end)
end

M.show_sign = function(hunk)
    for lnum = hunk.start, hunk.finish do
        vim.schedule(function()
            vim.fn.sign_place(lnum, state.sign.ns_id, state.sign.types[hunk.type].hl_group, hunk.filepath, {
                lnum = lnum,
                priority = state.sign.priority,
            })
        end)
    end
end

M.show_hunk = function(hunk)
    local padding = { 1, 2, 1, 2 }
    local content = pad_content(vim.deepcopy(hunk.diff), padding)
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, content)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'diff')

    for index, line in pairs(content) do
        -- Trim the string removing empty spaces.
        line = line:gsub('%s+', '')
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            vim.api.nvim_buf_add_highlight(bufnr, -1, state.hunk.types.add.hl_group, index - 1, 0, -1)
        elseif first_letter == '-' then
            vim.api.nvim_buf_add_highlight(bufnr, -1, state.hunk.types.remove.hl_group, index - 1, 0, -1)
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

    local win_id = vim.api.nvim_open_win(bufnr, false, {
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

M.show_files_changed = vim.schedule_wrap(function(files)
    opts = {}
    pickers.new(opts, {
        prompt_title = 'Git Changed Files',
        finder = finders.new_table {
            results = files,
            entry_maker = opts.entry_maker or make_entry.gen_from_string(opts),
        },
        previewer = conf.file_previewer(opts),
        sorter = conf.file_sorter(opts),
    }):find()
end)

M.show_diff = function(cwd_content, origin_content, file_type)
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

    vim.api.nvim_buf_set_lines(cwd_buf, 0, -1, false, cwd_content)
    vim.api.nvim_buf_set_lines(origin_buf, 0, -1, false, origin_content)

    highlight_with_ts(cwd_buf, file_type)
    highlight_with_ts(origin_buf, file_type)

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

    vim.api.nvim_win_set_option(cwd_win_id, 'winhl', 'Normal:' .. state.diff.window.hl_group)
    vim.api.nvim_win_set_option(cwd_win_id, 'cursorline', true)
    vim.api.nvim_win_set_option(cwd_win_id, 'wrap', false)
    -- When cursor bind on both buffer windows, moving cursor in one of the window will mimic the position in the other one.
    vim.api.nvim_win_set_option(cwd_win_id, 'cursorbind', true)

    vim.api.nvim_win_set_option(origin_win_id, 'winhl', 'Normal:' .. state.diff.window.hl_group)
    vim.api.nvim_win_set_option(origin_win_id, 'cursorline', true)
    vim.api.nvim_win_set_option(origin_win_id, 'wrap', false)
    vim.api.nvim_win_set_option(origin_win_id, 'cursorbind', true)

    -- Setup keymap.
    vim.api.nvim_buf_set_keymap(
        cwd_buf,
        'n',
        '<C-c>',
        string.format(':lua vim.api.nvim_win_close(%s, false)<CR>', cwd_win_id),
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        cwd_buf,
        'n',
        '<esc>',
        string.format(':lua vim.api.nvim_win_close(%s, false)<CR>', cwd_win_id),
        { silent = true }
    )

    -- Create close one window when the other one closes.
    vim.cmd(
        string.format(
            'autocmd BufWinLeave <buffer=%s> ++once call nvim_win_close(%s, v:false)',
            cwd_buf,
            origin_win_id
        )
    )
    vim.cmd(
        string.format(
            'autocmd BufWinLeave <buffer=%s> ++once call nvim_win_close(%s, v:false)',
            origin_buf,
            cwd_win_id
        )
    )
    -- Attach a autocmd to the original buffer, which when entered will close the window on the left.
    -- If the window on the left is closed, the window on the right is also closed from the autocmds above.
    vim.cmd(
        string.format(
            'autocmd BufWinEnter <buffer=%s> ++once call nvim_win_close(%s, v:false)',
            bufnr,
            cwd_win_id
        )
    )
end

return M
