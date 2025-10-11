local M = {}

function M.git_exec(args, opts)
  opts = opts or {}
  local result = vim.fn.system(args)
  local exit_code = vim.v.shell_error

  if opts.check and exit_code ~= 0 then return nil, 'Git command failed: ' .. result end

  return result, nil
end

function M.resolve_path(path)
  local resolved = vim.loop.fs_realpath(path)
  return resolved or path
end

function M.mkdir_p(path)
  local parts = {}
  for part in path:gmatch('[^/]+') do
    table.insert(parts, part)
  end

  local current = path:sub(1, 1) == '/' and '/' or ''
  for _, part in ipairs(parts) do
    current = current .. part
    local stat = vim.loop.fs_stat(current)
    if not stat then
      local success, err = vim.loop.fs_mkdir(current, 493)
      if not success and err ~= 'EEXIST' then return false end
    end
    current = current .. '/'
  end
  return true
end

function M.write_file_internal(filepath, content)
  local dir = vim.fn.fnamemodify(filepath, ':h')
  local stat = vim.loop.fs_stat(dir)
  if not stat then
    local success = M.mkdir_p(dir)
    if not success then return nil, 'Failed to create directory: ' .. dir end
  end

  local lines = type(content) == 'table' and content or { content }
  local result = vim.fn.writefile(lines, filepath)
  if result ~= 0 then return nil, 'Failed to write file: ' .. filepath end

  return true, nil
end

function M.rmdir_recursive(path)
  local handle = vim.loop.fs_scandir(path)
  if not handle then return false end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end

    local fullpath = path .. '/' .. name
    if type == 'directory' then
      if not M.rmdir_recursive(fullpath) then return false end
    else
      local success = vim.loop.fs_unlink(fullpath)
      if not success then return false end
    end
  end

  return vim.loop.fs_rmdir(path) ~= nil
end

return M
