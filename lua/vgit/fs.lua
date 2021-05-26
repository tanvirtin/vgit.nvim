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

M.project_relative_path = function(filepath, project_files)
    if filepath == '' then
        return filepath
    end
    for i = #filepath, 1, -1 do
        local letter = filepath:sub(i, i)
        local new_project_files = {}
        for _, candidate in ipairs(project_files) do
            local corrected_index = #candidate - (#filepath - i)
            local candidate_letter = candidate:sub(corrected_index, corrected_index)
            if letter == candidate_letter then
                table.insert(new_project_files, candidate)
            end
        end
        project_files = new_project_files
    end
    return project_files[1] or filepath
end

M.filetype = function(buf)
    return vim.api.nvim_buf_get_option(buf, 'filetype')
end

M.filename = function(buf)
    local filepath = vim.api.nvim_buf_get_name(buf)
    return M.relative_path(filepath)
end

M.read_file = function(filepath)
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

return M
