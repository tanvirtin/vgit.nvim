local Job = require('plenary.job')
local vim = vim

local M = {}

M.read_file = function(path)
    local data = ''
    local err_result = ''
    local job = Job:new({
        command = 'cat',
        args = { path },
        on_stdout = function(_, line)
            data = data .. line .. '\n'
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
        return err_result, nl
    end
    return nil, data
end

return M
