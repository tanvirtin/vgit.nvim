local buffer = require('vgit.buffer')
local assert = require('vgit.assertion').assert
local pfiletype = require('plenary.filetype')

local M = {}

M.cwd_filename = function(filepath)
  assert(type(filepath) == 'string', 'type error :: expected string')
  local end_index = nil
  for i = #filepath, 1, -1 do
    local letter = filepath:sub(i, i)
    if letter == '/' then
      end_index = i
    end
  end
  if not end_index then
    return ''
  end
  return filepath:sub(1, end_index)
end

M.relative_filename = function(filepath)
  assert(type(filepath) == 'string', 'type error :: expected string')
  local cwd = vim.loop.cwd()
  if not cwd or not filepath then
    return filepath
  end
  if filepath:sub(1, #cwd) == cwd then
    local offset = 0
    if cwd:sub(#cwd, #cwd) ~= '/' then
      offset = 1
    end
    filepath = filepath:sub(#cwd + 1 + offset, #filepath)
  end
  return filepath
end

M.short_filename = function(filepath)
  assert(type(filepath) == 'string', 'type error :: expected string')
  local filename = ''
  for i = #filepath, 1, -1 do
    local letter = filepath:sub(i, i)
    if letter == '/' then
      break
    end
    filename = letter .. filename
  end
  return filename
end

M.filename = function(buf)
  assert(type(buf) == 'number', 'type error :: expected number')
  local filepath = vim.api.nvim_buf_get_name(buf)
  return M.relative_filename(filepath)
end

M.filetype = function(buf)
  assert(type(buf) == 'number', 'type error :: expected number')
  return buffer.get_option(buf, 'filetype')
end

M.detect_filetype = pfiletype.detect

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
    return { 'File not found' }, nil
  end
  local stat = vim.loop.fs_fstat(fd)
  if stat.type ~= 'file' then
    return { 'File not found' }, nil
  end
  local data = vim.loop.fs_read(fd, stat.size, 0)
  if not vim.loop.fs_close(fd) then
    return { 'Failed to close file' }, nil
  end
  return nil, vim.split(data, '[\r]?\n')
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

M.exists = function(filepath)
  assert(type(filepath) == 'string', 'type error :: expected string')
  return (vim.loop.fs_stat(filepath) and true) or false
end

return M
