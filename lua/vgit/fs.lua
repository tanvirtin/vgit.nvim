local pfiletype = require('plenary.filetype')

local vim = vim

local M = {}

M.relative_path = function(filepath)
    assert(type(filepath) == 'string', 'type error :: expected string')
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

M.project_relative_filename = function(filepath, project_files)
    assert(type(filepath) == 'string', 'type error :: expected string')
    assert(vim.tbl_islist(project_files), 'type error :: expected table of type list')
    table.sort(project_files)
    if filepath == '' then
        return filepath
    end
    for i = #filepath, 1, -1 do
        local letter = filepath:sub(i, i)
        local new_project_files = {}
        for j = 1, #project_files do
            local candidate = project_files[j]
            local corrected_index = #candidate - (#filepath - i)
            local candidate_letter = candidate:sub(corrected_index, corrected_index)
            if letter == candidate_letter then
                new_project_files[#new_project_files + 1] = candidate
            end
        end
        project_files = new_project_files
    end
    return project_files[1]
end

M.filetype = function(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    return vim.api.nvim_buf_get_option(buf, 'filetype')
end

M.detect_filetype = pfiletype.detect

M.filename = function(buf)
    assert(type(buf) == 'number', 'type error :: expected number')
    local filepath = vim.api.nvim_buf_get_name(buf)
    return M.relative_path(filepath)
end

M.tmpname = function()
    local length = 6
    local res = ''
    for _ = 1, length do
        res = res .. string.char(math.random(97, 122))
    end
    return string.format('/tmp/%s_vgit', res)
end

M.read_file = function(filepath)
    assert(type(filepath) == 'string', 'type error :: expected string')
    local fd = vim.loop.fs_open(filepath, 'r', 438)
    if fd == nil then
        return { 'ENOENT: File not found' }, nil
    end
    local stat = vim.loop.fs_fstat(fd)
    if stat.type ~= 'file' then
        return { 'File not found' }, nil
    end
    local data = vim.loop.fs_read(fd, stat.size, 0)
    if not vim.loop.fs_close(fd) then
        return { 'Failed to close file' }, nil
    end
    return nil, vim.split(data, '\n')
end

M.write_file = function(filepath, lines)
    assert(type(filepath) == 'string', 'type error :: expected string')
    assert(vim.tbl_islist(lines), 'type error :: expected list table')
    local f = io.open(filepath, 'wb')
    for i = 1, #lines do
        local l = lines[i]
        f:write(l)
        f:write('\n')
    end
    f:close()
end

M.remove_file = function(filepath)
    assert(type(filepath) == 'string', 'type error :: expected string')
    return os.remove(filepath)
end

return M
