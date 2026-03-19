local fs = {}

fs.sep = package.config:sub(1, 1)

function fs.detect_filetype(filename)
  local ft = vim.filetype.match({ filename = filename })
  if ft then return ft end

  local strip_exts = {
    ['in'] = true,
    ['bak'] = true,
    ['old'] = true,
    ['new'] = true,
    ['orig'] = true,
    ['pacsave'] = true,
    ['pacnew'] = true,
    ['rpmsave'] = true,
    ['dpkg-bak'] = true,
    ['dpkg-dist'] = true,
    ['dpkg-old'] = true,
    ['dpkg-new'] = true,
  }

  local name = filename
  local _, num_dots = filename:gsub('%.', '')
  for _ = 1, num_dots do
    local ext = name:match('%.([^./\\]+)$')
    if not ext then break end

    if strip_exts[ext] then
      name = name:sub(1, #name - #ext - 1)
      ft = vim.filetype.match({ filename = name })
      if ft then return ft end
    else
      return vim.filetype.match({ filename = 'x.' .. ext })
    end
  end
end

function fs.make_relative(dirname, filepath)
  if not dirname or not filepath then return filepath end
  while #dirname > 1 and dirname:sub(-1) == fs.sep do
    dirname = dirname:sub(1, -2)
  end
  local prefix = dirname == fs.sep and fs.sep or (dirname .. fs.sep)
  if filepath:sub(1, #prefix) == prefix then return filepath:sub(#prefix + 1) end
  return filepath
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
  return vim.fn.readfile(filepath), nil
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

function fs.append_file(filepath, lines)
  local fd = io.open(filepath, 'ab')
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
  return vim.loop.fs_stat(filepath) ~= nil
end

function fs.dirname(filepath)
  return vim.fn.fnamemodify(filepath, ':h') or ''
end

function fs.absolute_path(base_path, relative_path)
  if relative_path:sub(1, 1) == '/' then return relative_path end
  -- Strip trailing separators to prevent double-slash
  while #base_path > 1 and base_path:sub(-1) == fs.sep do
    base_path = base_path:sub(1, -2)
  end
  if base_path == fs.sep then return fs.sep .. relative_path end
  return base_path .. fs.sep .. relative_path
end

function fs.is_dir(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return stat ~= nil and stat.type == 'directory'
end

function fs.resolve(filepath)
  return vim.fn.resolve(filepath)
end

function fs.chdir(dirpath)
  vim.cmd('cd ' .. vim.fn.fnameescape(dirpath))
end

function fs.open(filepath)
  vim.cmd(string.format('e %s', filepath))
end

return fs
