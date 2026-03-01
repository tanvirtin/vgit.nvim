local Object = require('vgit.core.Object')

local File = Object:extend()

function File:constructor(path)
  return {
    ['$_path'] = path,
    _fd = nil,
  }
end

function File:open(mode)
  self:close()
  self._fd = io.open(self._path, mode or 'ab')
  return self._fd ~= nil
end

function File:write(lines)
  if not self._fd then return nil, 'file not open' end
  for i = 1, #lines do
    self._fd:write(lines[i])
    self._fd:write('\n')
  end
  self._fd:flush()
  return true
end

function File:append(lines)
  if not self._fd then
    if not self:open('ab') then return nil, 'could not open file' end
  end
  return self:write(lines)
end

function File:close()
  if self._fd then
    self._fd:close()
    self._fd = nil
  end
end

function File:is_open()
  return self._fd ~= nil
end

function File:remove()
  self:close()
  return os.remove(self._path)
end

return File
