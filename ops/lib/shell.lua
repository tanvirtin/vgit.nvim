local M = {}

function M.file_exists(path)
  local handle = io.popen('test -f "' .. path .. '" && echo "true" || echo "false"')
  if not handle then return false end

  local result = handle:read('*l')
  handle:close()

  return result == 'true'
end

function M.dir_exists(path)
  local handle = io.popen('test -d "' .. path .. '" && echo "true" || echo "false"')
  if not handle then return false end

  local result = handle:read('*l')
  handle:close()

  return result == 'true'
end

function M.execute(cmd, output_file)
  local redirect = output_file and (' > ' .. output_file .. ' 2>&1') or ''
  local exit_code = os.execute(cmd .. redirect)

  if type(exit_code) == 'number' then
    return exit_code == 0
  else
    return exit_code
  end
end

function M.capture(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return nil, 'Could not execute command'
  end

  local output = handle:read('*a')
  local success = handle:close()
  return output, success
end

function M.tail(path, lines)
  local handle = io.popen('tail -' .. lines .. ' ' .. path)
  if not handle then return nil end

  local content = handle:read('*a')
  handle:close()
  return content
end

function M.normalize_exit_code(code)
  if type(code) == 'number' then
    return code == 0 and 0 or 1
  else
    return code and 0 or 1
  end
end

return M
