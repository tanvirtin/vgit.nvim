local Job = require('plenary.job')
local State = require('vgit.State')
local a = require('plenary.async_lib.async')
local wrap = a.wrap
local await = a.await
local async = a.async
local scheduler = a.scheduler

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
    local previous, current = unpack(
        vim.tbl_map(function(s)
            return vim.split(string.sub(s, 2), ',')
        end,
        vim.split(diffkey, ' '))
    )
    previous[1] = tonumber(previous[1])
    previous[2] = tonumber(previous[2]) or 1
    current[1] = tonumber(current[1])
    current[2] = tonumber(current[2]) or 1
    return previous, current
end

local M = {}

M.constants = {
    diff_algorithm = 'histogram',
    empty_tree_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
}

M.state = State.new({
    diff_base = 'HEAD',
    config = {},
})

M.get_diff_base = function()
    return M.state:get('diff_base')
end

M.set_diff_base = function(diff_base)
    M.state:set('diff_base', diff_base)
end

M.is_commit_valid = wrap(function(commit, callback)
    local result = {}
    local err = {}
    local job = Job:new({
        command = 'git',
        args = {
            'show',
            '--abbrev-commit',
            '--oneline',
            '--no-notes',
            '--no-patch',
            '--no-color',
            commit,
        },
        on_stdout = function(_, data, _)
            table.insert(result, data)
        end,
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(false)
            end
            if #result == 0 then
                return callback(false)
            end
            callback(true)
        end,
    })
    job:start()
end, 2)

M.create_log = function(line)
    local log = vim.split(line, '-')
    return {
        commit_hash = log[1]:sub(2, #log[1]),
        parent_hash = log[2],
        timestamp = log[3],
        author_name = log[4],
        author_email = log[5],
        summary = log[6]:sub(1, #log[6] - 1),
    }
end

M.create_hunk = function(header)
    local previous, current = parse_hunk_header(header)
    local hunk = {
        header = header,
        start = current[1],
        finish = current[1] + current[2] - 1,
        type = nil,
        diff = {},
    }
    if current[2] == 0 then
        -- If it's a straight remove with no change, then highlight only one sign column.
        hunk.finish = hunk.start
        hunk.type = 'remove'
    elseif previous[2] == 0 then
        hunk.type = 'add'
    else
        hunk.type = 'change'
    end
    return hunk
end

M.create_blame = function(info)
    local function split_by_whitespace(str)
        return vim.split(str, ' ')
    end
    local commit_hash_info = split_by_whitespace(info[1])
    local author_mail_info = split_by_whitespace(info[3])
    local author_time_info = split_by_whitespace(info[4])
    local author_tz_info = split_by_whitespace(info[5])
    local committer_mail_info = split_by_whitespace(info[7])
    local committer_time_info = split_by_whitespace(info[8])
    local committer_tz_info = split_by_whitespace(info[9])
    local parent_hash_info = split_by_whitespace(info[11])
    local author = info[2]:sub(8, #info[2])
    local author_mail = author_mail_info[2]
    local committer = info[6]:sub(11, #info[6])
    local committer_mail = committer_mail_info[2]
    local lnum = tonumber(commit_hash_info[3])
    local committed = true
    if author == 'Not Committed Yet'
        and committer == 'Not Committed Yet'
        and author_mail == '<not.committed.yet>'
        and committer_mail == '<not.committed.yet>' then
        committed = false
    end
    return {
        lnum = lnum,
        commit_hash = commit_hash_info[1],
        parent_hash = parent_hash_info[2],
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
        commit_message = info[10]:sub(9, #info[10]),
        committed = committed,
    }
end

M.setup = async(function(config)
    M.state:assign(config)
    local err, git_config = await(M.config())
    await(scheduler())
    if not err then
        M.state:set('config', git_config)
    end
end)

M.config = wrap(function(callback)
    local err = {}
    local result = {}
    local job = Job:new({
        command = 'git',
        args = {
            'config',
            '--list',
        },
        on_stdout = function(_, line)
            local line_chunks = vim.split(line, '=')
            result[line_chunks[1]] = line_chunks[2]
        end,
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(err, nil)
            end
            callback(nil, result)
        end,
    })
    job:start()
end, 1)

M.is_inside_work_tree = wrap(function(callback)
    local err = {}
    local job = Job:new({
        command = 'git',
        args = {
            'rev-parse',
            '--is-inside-work-tree',
        },
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(false)
            end
            callback(true)
        end,
    })
    job:start()
end, 1)

M.blame_line = wrap(function(filename, lnum, callback)
    local err = {}
    local result = {}
    local job = Job:new({
        command = 'git',
        args = {
            'blame',
            '-L',
            string.format('%s,+1', lnum),
            '--line-porcelain',
            '--',
            filename,
        },
        on_stdout = function(_, data, _)
            table.insert(result, data)
        end,
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(err, nil)
            end
            callback(nil, M.create_blame(result))
        end,
    })
    job:start()
end, 3)

M.logs = wrap(function(filename, callback)
    local logs = {{
        author_name = M.state:get('config')['user.name'],
        author_email = M.state:get('config')['user.email'],
        commit_hash = nil,
        parent_hash = nil,
        summary = nil,
        timestamp = nil
    }}
    local job = Job:new({
        command = 'git',
        args = {
            'log',
            '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
            '--',
            filename,
        },
    })
    job:start()
    -- BUG: Plenary Job bug, prevents last line to be read.
    job:wait()
    local result = job:result()
    for _, line in ipairs(result) do
        table.insert(logs, M.create_log(line))
    end
    local err = job:stderr_result()
    if #err ~= 0 then
        return callback(err, nil)
    end
    return callback(nil, logs)
end, 2)

M.hunks = wrap(function(filename, parent_hash, commit_hash, callback)
    local result = {}
    local err = {}
    local args = {
        '--no-pager',
        '-c',
        'core.safecrlf=false',
        'diff',
        '--color=never',
        string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
        '--patch-with-raw',
        '--unified=0',
        M.state:get('diff_base'),
        '--',
        filename,
    }
    if parent_hash and not commit_hash then
        args = {
            '--no-pager',
            '-c',
            'core.safecrlf=false',
            'diff',
            '--color=never',
            string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
            '--patch-with-raw',
            '--unified=0',
            parent_hash,
            '--',
            filename,
        }
    end
    if parent_hash and commit_hash then
        args = {
            '--no-pager',
            '-c',
            'core.safecrlf=false',
            'diff',
            '--color=never',
            string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
            '--patch-with-raw',
            '--unified=0',
            #parent_hash > 0 and parent_hash or M.constants.empty_tree_hash,
            commit_hash,
            '--',
            filename,
        }
    end
    local job = Job:new({
        command = 'git',
        args = args,
        on_stdout = function(_, data, _)
            table.insert(result, data)
        end,
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(err, nil)
            end
            local hunks = {}
            for _, line in ipairs(result) do
                if vim.startswith(line, '@@') then
                    table.insert(hunks, M.create_hunk(line))
                else
                    if #hunks > 0 then
                        local hunk = hunks[#hunks]
                        table.insert(hunk.diff, line)
                    end
                end
            end
            return callback(nil, hunks)
        end,
    })
    job:start()
end, 4)

M.show = wrap(function(filename, commit_hash, callback)
    local err = {}
    local result = {}
    commit_hash = commit_hash or ''
    local job = Job:new({
        command = 'git',
        args = {
            'show',
            string.format('%s:%s', commit_hash, filename),
        },
        on_stdout = function(_, data, _)
            table.insert(result, data)
        end,
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(err, nil)
            end
            callback(nil, result)
        end,
    })
    job:sync()
end, 3)

M.reset = wrap(function(filename, callback)
    local err = {}
    local job = Job:new({
        command = 'git',
        args = {
            'checkout',
            'HEAD',
            '--',
            filename,
        },
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(err)
            end
            callback(nil)
        end,
    })
    job:start()
end, 2)

M.ls_tracked = wrap(function(callback)
    local err = {}
    local result = {}
    local job = Job:new({
        command = 'git',
        args = {
            'ls-files',
            '--full-name',
        },
        on_stdout = function(_, data, _)
            table.insert(result, data)
        end,
        on_stderr = function(_, data, _)
            table.insert(err, data)
        end,
        on_exit = function()
            if #err ~= 0 then
                return callback(err, result)
            end
            callback(nil, result)
        end,
    })
    job:start()
end, 1)

M.horizontal_diff = wrap(function(lines, hunks, callback)
    if #hunks == 0 then
        return callback(nil, {
            lines = lines,
            lnum_changes = {},
        })
    end
    local new_lines = {}
    local lnum_changes = {}
    for key, value in pairs(lines) do
        new_lines[key] = value
    end
    local new_lines_added = 0
    for _, hunk in ipairs(hunks) do
        local type = hunk.type
        local diff = hunk.diff
        local start = hunk.start + new_lines_added
        local finish = hunk.finish + new_lines_added
        if type == 'add' then
            for i = start, finish do
                table.insert(lnum_changes, {
                    lnum = i,
                    type = 'add'
                })
            end
        elseif type == 'remove' then
            local s = start
            for _, line in ipairs(diff) do
                s = s + 1
                new_lines_added = new_lines_added + 1
                table.insert(new_lines, s, line:sub(2, #line))
                table.insert(lnum_changes, {
                    lnum = s,
                    type = 'remove'
                })
            end
        elseif type == 'change' then
            local s = start
            for _, line in ipairs(diff) do
                local line_type = line:sub(1, 1)
                if line_type == '-' then
                    new_lines_added = new_lines_added + 1
                    table.insert(new_lines, s, line:sub(2, #line))
                    table.insert(lnum_changes, {
                        lnum = s,
                        type = 'remove'
                    })
                elseif line_type == '+' then
                    table.insert(lnum_changes, {
                        lnum = s,
                        type = 'add'
                    })
                end
                s = s + 1
            end
        end
    end
    return callback(nil, {
        lines = new_lines,
        lnum_changes = lnum_changes,
    })
end, 3)

M.vertical_diff = wrap(function(lines, hunks, callback)
    if #hunks == 0 then
        return callback(nil, {
            current_lines = lines,
            previous_lines = lines,
            lnum_changes = {},
        })
    end
    local current_lines = {}
    local previous_lines = {}
    local lnum_changes = {}
    -- shallow copy
    for key, value in pairs(lines) do
        current_lines[key] = value
        previous_lines[key] = value
    end
    -- Operations below will potentially add more lines to both current and
    -- previous data, which means, the offset needs to be added to our hunks.
    local new_lines_added = 0
    for _, hunk in ipairs(hunks) do
        local type = hunk.type
        local start = hunk.start + new_lines_added
        local finish = hunk.finish + new_lines_added
        local diff = hunk.diff
        if type == 'add' then
            -- Remove the line indicating that these lines were inserted in current_lines.
            for i = start, finish do
                previous_lines[i] = ''
                table.insert(lnum_changes, {
                    lnum = i,
                    buftype = 'current',
                    type = 'add'
                })
            end
        elseif type == 'remove' then
            for _, line in ipairs(diff) do
                start = start + 1
                new_lines_added = new_lines_added + 1
                table.insert(current_lines, start, '')
                table.insert(previous_lines, start, line:sub(2, #line))
                table.insert(lnum_changes, {
                    lnum = start,
                    buftype = 'previous',
                    type = 'remove'
                })
            end
        elseif type == 'change' then
            -- Retrieve lines that have been removed and added without "-" and "+".
            local removed_lines, added_lines = parse_hunk_diff(diff)
            -- Max lines are the maximum number of lines found between added and removed lines.
            local max_lines
            if #removed_lines > #added_lines then
                max_lines = #removed_lines
            else
                max_lines = #added_lines
            end
            -- Hunk finish index does not indicate the total number of lines that may have a diff.
            -- Which is why I am inserting empty lines into both the current and previous data arrays.
            for i = finish + 1, (start + max_lines) - 1 do
                new_lines_added = new_lines_added + 1
                table.insert(current_lines, i, '')
                table.insert(previous_lines, i, '')
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
                        buftype = 'previous',
                        type = 'remove'
                    })
                end
                if added_line then
                    table.insert(lnum_changes, {
                        lnum = i,
                        buftype = 'current',
                        type = 'add'
                    })
                end
                previous_lines[i] = removed_line or ''
                current_lines[i] = added_line or ''
            end
        end
    end
    return callback(nil, {
        current_lines = current_lines,
        previous_lines = previous_lines,
        lnum_changes = lnum_changes,
    })
end, 3)

return M
