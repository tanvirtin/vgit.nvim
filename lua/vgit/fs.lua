local Job = require('plenary.job')

local vim = vim

local M = {}

M.relative_path = function(filepath)
    local cwd = vim.loop.cwd()
    if not cwd or not filepath then return filepath end
    if filepath:sub(1, #cwd) == cwd  then
        local offset =  0
        if cwd:sub(#cwd, #cwd) ~= '/' then
            offset = 1
        end
        filepath = filepath:sub(#cwd + 1 + offset, #filepath)
    end
    return filepath
end

M.filename = function(buf)
    local filepath = vim.api.nvim_buf_get_name(buf)
    return M.relative_path(filepath)
end

M.read_file = function(filepath)
    local data = ''
    local err_result = ''
    local job = Job:new({
        command = 'cat',
        args = { filepath },
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
        return err_result, nil
    end
    data = vim.split(data, '\n')
    return nil, data
end

return M
