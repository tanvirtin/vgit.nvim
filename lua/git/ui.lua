local highlight = require('git.highlight')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local conf = require('telescope.config').values

local M = {}

local state = {
    hunk = {
        types = {
            add = {
                hl_group = 'GitHunkAdd',
                bg = nil,
                fg = '#d7ffaf',
            },
            remove = {
                hl_group = 'GitHunkRemove',
                bg = nil,
                fg = '#e95678',
            },
        },
        window = {
            hl_group = 'GitHunk',
            fg = '#ffffff',
            bg = nil,
            border = {{ '╭' }, { '─' }, { '╮' }, { '│' }, { '╯' }, { '─' }, { '╰' }, { '│' }}
        }
    },
    sign = {
        ns_id = 'git',
        priority = 10,
        types = {
            add = {
                hl_group = 'GitAdd',
                bg = '#d7ffaf',
                fg = nil,
                text = ' '
            },
            remove = {
                hl_group = 'GitRemove',
                bg = '#e95678',
                fg = nil,
                text = ' '
            },
            change = {
                hl_group = 'GitChange',
                bg = '#7AA6DA',
                fg = nil,
                text = ' '
            },
        },
    }
}

local function add_highlight(group, color)
    local style = color.style and "gui=" .. color.style or "gui=NONE"
    local fg = color.fg and "guifg = " .. color.fg or "guifg = NONE"
    local bg = color.bg and "guibg = " .. color.bg or "guibg = NONE"
    local sp = color.sp and "guisp = " .. color.sp or ""
    vim.api.nvim_command("highlight " .. group .. " " .. style .. " " .. fg .. " " .. bg .. " " .. sp)
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

M.initialize = function()
    for _, action in pairs(state.hunk.types) do
        add_highlight(action.hl_group, action);
    end
    for key, type in pairs(state.sign.types) do
        add_highlight(state.sign.types[key].hl_group, state.sign.types[key])
        vim.fn.sign_define(type.hl_group, {
            text = type.text,
            texthl = type.hl_group
        })
    end
    -- TODO
    add_highlight(state.hunk.window.hl_group, state.hunk.window)
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
    local padding = { 1, 3, 1, 3 }
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

    local width = 25
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

return M
