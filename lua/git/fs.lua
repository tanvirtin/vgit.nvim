local Job = require('plenary.job')
local vim = vim

local M = {}

M.read_file = function(path, callback)
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
        on_exit = function()
            if err_result ~= '' then
                return callback(err_result, nil)
            end
            callback(nil, data)
        end,
    })
    job:sync()
    return job
end

M.file_type = function(filename)
    local extension_split = vim.split(filename, '.', true)
    if #extension_split == 1 then
        return ''
    end
    return extension_split[#extension_split]
end

return M
