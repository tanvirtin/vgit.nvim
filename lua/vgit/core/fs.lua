local Path = require('plenary.path')
local plenary_filetype = require('plenary.filetype')

local fs = {}

fs.sep = Path.path.sep
fs.detect_filetype = plenary_filetype.detect

function fs.make_relative(dirname, filepath)
  return Path:new(filepath):make_relative(dirname)
end

function fs.relative_filename(filepath)
  return fs.make_relative(vim.loop.cwd(), filepath)
end

function fs.short_filename(filepath)
  local filename = ''

  for i = #filepath, 1, -1 do
    local letter = filepath:sub(i, i)
    if letter == fs.sep then break end
    filename = letter .. filename
  end

  return filename
end

function fs.tmpname()
  return os.tmpname()
end

function fs.filetype(buffer)
  return buffer:get_option('filetype')
end

function fs.read_file(filepath)
  if not fs.exists(filepath) then return nil, { 'file not found' } end
  return vim.fn.readfile(filepath)
end

function fs.write_file(filepath, lines)
  local fd = io.open(filepath, 'wb')
  if not fd then return nil, { 'no file descriptor found' } end

  for i = 1, #lines do
    fd:write(lines[i])
    fd:write('\n')
  end

  fd:close()
end

function fs.remove_file(filepath)
  return os.remove(filepath)
end

function fs.exists(filepath)
  return (vim.loop.fs_stat(filepath) and true) or false
end

function fs.dirname(filepath)
  return vim.fn.fnamemodify(filepath, ':h') or ''
end

function fs.is_dir(filepath)
  return Path:new(filepath):is_dir()
end

function fs.open(filepath)
  vim.cmd(string.format('e %s', filepath))

  return fs
end

return fs
