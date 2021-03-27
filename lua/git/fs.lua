local uv = vim.loop

local M = {}

M.read_file = function(path, callback)
    uv.fs_open(path, "r", 438, function(err, fd)
        if err then
            return callback(err, nil)
        end
        uv.fs_fstat(fd, function(err, stat)
            if err then
                return callback(err, nil)
            end
            uv.fs_read(fd, stat.size, 0, function(err, data)
                if err then
                    return callback(err, nil)
                end
                uv.fs_close(fd, function(err)
                    if err then
                        return callback(err, nil)
                    end
                    callback(nil, data)
                end)
            end)
        end)
    end)
end

M.get_file_type = function(filepath)
    local os_sep = nil
    if jit then
        local os = string.lower(jit.os)
        if os == 'linux' or os == 'osx' or os == 'bsd' then
            os_sep = '/'
        else
            os_sep = '\\'
        end
    else
        os_sep = package.config:sub(1, 1)
    end
    if not os_sep then
        return ''
    end
    local split_path = vim.split(filepath, os_sep, true)
    local filename = split_path[#split_path]
    local extension_split = vim.split(filepath, '.', true)
    return extension_split[#extension_split]
end

return M
