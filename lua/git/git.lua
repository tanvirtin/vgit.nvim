local Job = require('plenary.job')
local fs = require('git.fs')

local vim = vim
local unpack = unpack

local function parse_hunk_diff(diff)
    local removed_lines = {}
    local added_lines = {}
    for _, line in ipairs(diff) do
        local type = line:sub(1, 1)
        local cleaned_diff_line = line:sub(2, #line)
        if type == '+' then
            table.insert(added_lines, cleaned_diff_line)
        elseif type == '-' then
            table.insert(removed_lines, cleaned_diff_line)
        end
    end
    return removed_lines, added_lines
end

local function parse_hunk_header(line)
    local diffkey = vim.trim(vim.split(line, '@@', true)[2])
    local origin, current = unpack(
        vim.tbl_map(function(s)
            return vim.split(string.sub(s, 2), ',')
        end,
        vim.split(diffkey, ' '))
    )
    origin[1] = tonumber(origin[1])
    origin[2] = tonumber(origin[2]) or 1
    current[1] = tonumber(current[1])
    current[2] = tonumber(current[2]) or 1
    return origin, current
end

local M = {}

local function get_initial_state()
    return {
        diff_algorithm = 'histogram'
    }
end

local state = get_initial_state()

M.initialize = function()
end

M.tear_down = function()
    state = get_initial_state()
end

M.create_hunk = function(header)
    local origin, current = parse_hunk_header(header)

    local hunk = {
        start = current[1],
        finish = current[1] + current[2] - 1,
        type = nil,
        diff = {},
    }

    if current[2] == 0 then
        -- If it's a straight remove with no change, then highlight only one sign column.
        hunk.finish = hunk.start
        hunk.type = 'remove'
    elseif origin[2] == 0 then
        hunk.type = 'add'
    else
        hunk.type = 'change'
    end

    return hunk
end

M.buffer_hunks = function(filepath, callback)
    local errResult = ''
    local hunks = {}
    local job = Job:new({
        command = 'git',
        args = {
            '--no-pager',
            '-c',
            'core.safecrlf=false',
            'diff',
            '--color=never',
            string.format('--diff-algorithm=%s', state.diff_algorithm),
            '--patch-with-raw',
            '--unified=0',
            filepath,
        },
        on_stdout = function(_, line)
            if vim.startswith(line, '@@') then
                table.insert(hunks, M.create_hunk(line))
            else
                if #hunks > 0 then
                    local hunk = hunks[#hunks]
                    table.insert(hunk.diff, line)
                end
            end
        end,
        on_stderr = function(err, line)
            if err then
                errResult = errResult .. err
            elseif line then
                errResult = errResult .. line
            end
        end,
        on_exit = function()
            if errResult ~= '' then
                return callback(errResult, nil)
            end
            callback(nil, hunks)
        end,
    })
    job:sync()
    return job
end

M.diff = function(filepath, hunks, callback)
    fs.read_file(filepath, vim.schedule_wrap(function(err, data)
        if err then
            return callback(err, nil, nil, nil)
        end
        local file_type = fs.file_type(filepath)
        data = vim.split(data, '\n')
        local cwd_data = {}
        local origin_data = {}
        local lnum_changes = {
            origin = {
                added = {},
                removed = {}
            },
            cwd = {
                added = {},
                removed = {}
            },
        }
        -- shallow copy
        for key, value in pairs(data) do
            cwd_data[key] = value
            origin_data[key] = value
        end
        -- Operations below will potentially add more lines to both cwd and
        -- origin data, which means, the offset needs to be added to our hunks.
        local new_lines_added = 0
        for _, hunk in ipairs(hunks) do
            local type = hunk.type
            local start = hunk.start + new_lines_added
            local finish = hunk.finish + new_lines_added
            local diff = hunk.diff
            if type == 'add' then
                -- Remove the line indicating that these lines were inserted in cwd_data.
                for i = start, finish do
                    origin_data[i] = ''
                    table.insert(lnum_changes.cwd.added, i)
                end
            elseif type == 'remove' then
                for _, line in ipairs(diff) do
                    start = start + 1
                    new_lines_added = new_lines_added + 1
                    table.insert(cwd_data, start, '')
                    table.insert(origin_data, start, line:sub(2, #line))
                    table.insert(lnum_changes.origin.removed, start)
                end
            elseif type == 'change' then
                -- Retrieve lines that have been removed and added without "-" and "+".
                local removed_lines, added_lines = parse_hunk_diff(diff)
                -- Max lines are the maximum number of lines found between added and removed lines.
                local max_lines = 0
                if #removed_lines > #added_lines then
                    max_lines = #removed_lines
                else
                    max_lines = #added_lines
                end
                -- Hunk finish index does not indicate the total number of lines that may have a diff.
                -- Which is why I am inserting empty lines into both the cwd and origin data arrays.
                for i = finish + 1, (start + max_lines) - 1 do
                    new_lines_added = new_lines_added + 1
                    table.insert(cwd_data, i, '')
                    table.insert(origin_data, i, '')
                end
                -- With the new calculated range I simply loop over and add the removed
                -- and added lines to their corresponding arrays that contain a buffer lines.
                for i = start, start + max_lines - 1 do
                    local recalculated_index = (i - start) + 1
                    local added_line = added_lines[recalculated_index]
                    local removed_line = removed_lines[recalculated_index]
                    if removed_line then
                        table.insert(lnum_changes.origin.removed, i)
                    end
                    if added_line then
                        table.insert(lnum_changes.cwd.added, i)
                    end
                    origin_data[i] = removed_line or ''
                    cwd_data[i] = added_line or ''
                end
            end
        end
        callback(nil, cwd_data, origin_data, lnum_changes, file_type)
    end));
end

return M
