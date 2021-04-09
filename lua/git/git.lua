local Job = require('plenary.job')
local fs = require('git.fs')
local Hunk = require('git.hunk')

local vim = vim

local M = {}

local state = {
    diff_algorithm = 'myers'
}

local function trim_diff_line(line)
    return line:sub(2, #line)
end

local function get_diff_type(line)
    return line:sub(1, 1)
end

local function parse_diff(diff)
    local removed_lines = {}
    local added_lines = {}
    for _, line in ipairs(diff) do
        local type = get_diff_type(line)
        local trimmed_line = trim_diff_line(line)
        if type == '+' then
            table.insert(added_lines, trimmed_line)
        elseif type == '-' then
            table.insert(removed_lines, trimmed_line)
        end
    end
    return removed_lines, added_lines
end

M.initialize = function()
end

M.tear_down = function()
    state = nil
end

M.diff = function(filepath, callback)
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
                table.insert(hunks, Hunk:new(filepath, line))
            else
                if #hunks > 0 then
                    local lastHunk = hunks[#hunks]
                    lastHunk:add_line(line)
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

M.status = function(callback)
    local errResult = ''
    local files = {}

    local job = Job:new({
        command = 'git',
        args = {
            'status',
            '-s',
        },
        on_stdout = function(_, line)
            -- Each line will have a format of "${status} ${filepath}"
            local filepath_start_index = 1;
            local filepath_end_index = #line;
            for i = 1, #line do
                local c = line:sub(i,i)
                if c == ' ' then
                    filepath_start_index = i + 1
                    local status = line:sub(1, i - 1)
                    if status == ' D' then
                        return
                    end
                end
            end
            line = line:sub(filepath_start_index, filepath_end_index)
            table.insert(files, line)
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
            callback(nil, files)
        end,
    })
    job:sync()
    return job
end

M.get_diffed_content = function(filepath, hunks, callback)
    fs.read_file(filepath, vim.schedule_wrap(function(err, data)
        if err then
            return callback(err, nil, nil, nil)
        end
        local file_type = fs.get_file_type(filepath)
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
                    new_lines_added = new_lines_added + 1
                    table.insert(cwd_data, start, '')
                    table.insert(origin_data, start, trim_diff_line(line))
                    table.insert(lnum_changes.origin.removed, start)
                    -- Since an element has already been inserted, the start index increments by one to indicte the new insertion pos.
                    start = start + 1
                end
            elseif type == 'change' then
                -- Retrieve lines that have been removed and added without "-" and "+".
                local removed_lines, added_lines = parse_diff(diff)
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
