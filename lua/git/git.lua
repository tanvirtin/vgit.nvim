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

local function split_by(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local chunks = {}
    for s in string.gmatch(str, '([^' .. sep .. ']+)') do
        table.insert(chunks, s)
    end
    return chunks
end

local M = {}

local constants = {
    diff_algorithm = 'histogram'
}

local function get_initial_state()
    return { config = {} }
end

local state = get_initial_state()

M.setup = function()
    local err, config = M.config()
    if not err then
        state.config = config
    end
end

M.tear_down = function()
    state = get_initial_state()
end

M.get_state = function()
    -- TODO: Directly returning object in memory (Pros: No computation wasted for cloning, Cons: Mutable object)
    return state
end

M.config = function()
    local config = {}
    local err_result = ''
    local job = Job:new({
        command = 'git',
        args = {
            'config',
            '--list',
        },
        on_stdout = function(_, line)
            local line_chunks = split_by(line, '=')
            config[line_chunks[1]] = line_chunks[2]
        end,
        on_stderr = function(err, line)
            if err then
                err_result = err_result .. err
            elseif line then
                err_result = err_result .. line
            end
        end,
    })
    job:sync()
    job:wait()
    if err_result ~= '' then
        return err_result, nil
    end
    return nil, config
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

M.buffer_hunks = function(filename)
    local err_result = ''
    local hunks = {}
    local job = Job:new({
        command = 'git',
        args = {
            '--no-pager',
            '-c',
            'core.safecrlf=false',
            'diff',
            '--color=never',
            string.format('--diff-algorithm=%s', constants.diff_algorithm),
            '--patch-with-raw',
            '--unified=0',
            filename,
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
                err_result = err_result .. err
            elseif line then
                err_result = err_result .. line
            end
        end,
    })
    job:sync()
    job:wait()
    if err_result ~= '' then
        return err_result, nil
    end
    return nil, hunks
end

M.create_blame = function(info)
    local function split_by_whitespace(str)
        return split_by(str, ' ')
    end
    local hash_info = split_by_whitespace(info[1])
    local author_info = split_by_whitespace(info[2])
    local author_mail_info = split_by_whitespace(info[3])
    local author_time_info = split_by_whitespace(info[4])
    local author_tz_info = split_by_whitespace(info[5])
    local committer_info = split_by_whitespace(info[6])
    local committer_mail_info = split_by_whitespace(info[7])
    local committer_time_info = split_by_whitespace(info[8])
    local committer_tz_info = split_by_whitespace(info[9])
    local previous_hash_info = split_by_whitespace(info[11])
    local author = author_info[2]
    local author_mail = author_mail_info[2]
    local committer = committer_info[2]
    local committer_mail = committer_mail_info[2]
    local lnum = tonumber(hash_info[3])
    local committed = true
    if author == 'Not'
        and committer == 'Not'
        and author_mail == '<not.committed.yet>'
        and committer_mail == '<not.committed.yet>' then
        committed = false
    end
    return {
        lnum = lnum,
        hash = hash_info[1],
        previous_hash = previous_hash_info[2],
        author = author,
        author_mail = (function()
            local mail = author_mail
            if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
                mail = mail:sub(2, #mail - 1)
            end
            return mail
        end)(),
        author_time = tonumber(author_time_info[2]),
        author_tz = author_tz_info[2],
        committer = committer,
        committer_mail = (function()
            local mail = committer_mail
            if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
                mail = mail:sub(2, #mail - 1)
            end
            return mail
        end)(),
        committer_time = tonumber(committer_time_info[2]),
        committer_tz = committer_tz_info[2],
        commit_message = info[10],
        committed = committed,
    }
end

M.buffer_blames = function(filename)
    local err_result = ''
    local blames = {}
    local blame_info = {}
    local job = Job:new({
        command = 'git',
        args = {
            'blame',
            '--line-porcelain',
            filename,
        },
        on_stdout = function(_, line)
            if string.byte(line:sub(1, 3)) ~= 9 then
                table.insert(blame_info, line)
            else
                local blame = M.create_blame(blame_info)
                if blame then
                    blames[blame.lnum] = blame
                end
                blame_info = {}
            end
        end,
        on_stderr = function(err, line)
            if err then
                err_result = err_result .. err
            elseif line then
                err_result = err_result .. line
            end
        end,
    })
    job:sync()
    job:wait()
    if err_result ~= '' then
        return err_result, nil
    end
    return nil, blames
end

M.buffer_diff = function(filename, hunks)
    local err, data = fs.read_file(filename);
    if err then
        return err, nil
    end
    data = vim.split(data, '\n')
    local cwd_lines = {}
    local origin_lines = {}
    local lnum_changes = {}
    -- shallow copy
    for key, value in pairs(data) do
        cwd_lines[key] = value
        origin_lines[key] = value
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
            -- Remove the line indicating that these lines were inserted in cwd_lines.
            for i = start, finish do
                origin_lines[i] = ''
                table.insert(lnum_changes, {
                    lnum = i,
                    buftype = 'cwd',
                    type = 'add'
                })
            end
        elseif type == 'remove' then
            for _, line in ipairs(diff) do
                start = start + 1
                new_lines_added = new_lines_added + 1
                table.insert(cwd_lines, start, '')
                table.insert(origin_lines, start, line:sub(2, #line))
                table.insert(lnum_changes, {
                    lnum = start,
                    buftype = 'origin',
                    type = 'remove'
                })
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
                table.insert(cwd_lines, i, '')
                table.insert(origin_lines, i, '')
            end
            -- With the new calculated range I simply loop over and add the removed
            -- and added lines to their corresponding arrays that contain a buffer lines.
            for i = start, start + max_lines - 1 do
                local recalculated_index = (i - start) + 1
                local added_line = added_lines[recalculated_index]
                local removed_line = removed_lines[recalculated_index]
                if removed_line then
                    table.insert(lnum_changes, {
                        lnum = i,
                        buftype = 'origin',
                        type = 'remove'
                    })
                end
                if added_line then
                    table.insert(lnum_changes, {
                        lnum = i,
                        buftype = 'cwd',
                        type = 'add'
                    })
                end
                origin_lines[i] = removed_line or ''
                cwd_lines[i] = added_line or ''
            end
        end
    end
    return nil, {
        cwd_lines = cwd_lines,
        origin_lines = origin_lines,
        lnum_changes = lnum_changes,
    }
end

M.buffer_reset = function(filename)
    local err_result = ''
    local job = Job:new({
        command = 'git',
        args = {
            'checkout',
            'HEAD',
            '--',
            filename,
        },
        on_stderr = function(err, line)
            if err then
                err_result = err_result .. err
            elseif line then
                err_result = err_result .. line
            end
        end,
    })
    job:sync()
    job:wait()
    if err_result ~= '' then
        return err_result
    end
    return nil
end

return M
