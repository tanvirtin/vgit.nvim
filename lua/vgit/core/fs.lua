local Path = require('plenary.path')
local pfiletype = require('plenary.filetype')

local fs = {}

fs.cwd_filename = function(filepath)
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

fs.relative_filename = function(filepath)
  return Path:new(filepath):make_relative(vim.loop.cwd())
end

fs.short_filename = function(filepath)
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

fs.filetype = function(buffer)
  return buffer:get_option('filetype')
end

fs.detect_filetype = pfiletype.detect

fs.tmpname = function()
  local length = 6
  local res = ''
  for _ = 1, length do
    res = res .. string.char(math.random(97, 122))
  end
  return string.format('/tmp/%s_vgit', res)
end

fs.read_file = function(filepath)
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
  local split_data = {}
  local line = ''
  for i = 1, #data do
    local word = data:sub(i, i)
    if word == '\n' or word == '\r' then
      split_data[#split_data + 1] = line
      line = ''
    else
      line = line .. word
    end
  end
  if not line == '' then
    split_data[#split_data + 1] = line
  end
  return nil, split_data
end

fs.write_file = function(filepath, lines)
  local f = io.open(filepath, 'wb')
  for i = 1, #lines do
    f:write(lines[i])
    f:write('\n')
  end
  f:close()
end

fs.remove_file = function(filepath)
  return os.remove(filepath)
end

fs.exists = function(filepath)
  return (vim.loop.fs_stat(filepath) and true) or false
end

fs.dirname = function(filepath)
  return filepath:match('(.*[/\\])') or ''
end

fs.is_dir = function(filepath)
  return Path:new(filepath):is_dir()
end

return fs
