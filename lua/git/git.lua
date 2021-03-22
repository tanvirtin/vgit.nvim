local Job = require('plenary.job')
local Hunk = require('git.hunk')

local git = {}

git.diff = function(filepath, callback)
    local errResult = ''
    local hunks = {}
    local diff_algo = 'myers'

    job = Job:new({
        command = 'git',
        args = {
            '--no-pager',
            '-c', 'core.safecrlf=false',
            'diff',
            '--color=never',
            '--diff-algorithm=' .. diff_algo,
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
                    lastHunk:add_diff(line)
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
    job:start()
end

return git
