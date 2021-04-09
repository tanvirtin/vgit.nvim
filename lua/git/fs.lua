local vim = vim
local uv = vim.loop

local M = {}

M.read_file = function(path, callback)
    uv.fs_open(path, 'r', 438, function(open_err, fd)
        if open_err then
            return callback(open_err, nil)
        end
        uv.fs_fstat(fd, function(fsstat_err, stat)
            if fsstat_err then
                return callback(fsstat_err, nil)
            end
            uv.fs_read(fd, stat.size, 0, function(read_err, data)
                if read_err then
                    return callback(read_err, nil)
                end
                uv.fs_close(fd, function(close_err)
                    if close_err then
                        return callback(close_err, nil)
                    end
                    callback(nil, data)
                end)
            end)
        end)
    end)
end

M.get_file_type = function(filepath)
    local extension_split = vim.split(filepath, '.', true)
    if #extension_split == 1 then
        return ''
    end
    return extension_split[#extension_split]
end

return M
