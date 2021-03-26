local Job = require('git.job')
local Hunk = require('git.hunk')
local log = require('git.log')

local M = {}

local state = {
    diff_algorithm = 'myers'
}

M.initialize = function()
end

M.tear_down = function()
    state = nil
end

M.diff = function(filepath, callback)
    local errResult = ''
    local hunks = {}

    job = Job:new({
        command = 'git',
        args = {
            '--no-pager',
            '-c',
            'core.safecrlf=false',
            'diff',
            '--color=never',
            '--diff-algorithm=' .. state.diff_algorithm,
            '--patch-with-raw',
            '--unified=0',
            filepath,
        },
        on_stdout = function(_, line)
            if vim.startswith(line, '@@') then
                table.insert(hunks, Hunk:new(filepath, line))
            else
                if #hunks > 0 then
                    lastHunk = hunks[#hunks]
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
end

M.status = function(callback)
    local errResult = ''
    local files = {}

    job = Job:new({
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
end

return M
