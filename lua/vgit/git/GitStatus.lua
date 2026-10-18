local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')

local GitStatus = Object:extend()

GitStatus.ARROW = ' -> '

GitStatus.ESCAPES = {
  a = '\a',
  b = '\b',
  f = '\f',
  n = '\n',
  r = '\r',
  t = '\t',
  v = '\v',
}

function GitStatus:unescape(body)
  local out = {}
  local i = 1
  while i <= #body do
    local char = body:sub(i, i)
    if char ~= '\\' then
      out[#out + 1] = char
      i = i + 1
    else
      local octal = body:match('^[0-7][0-7][0-7]', i + 1)
      if octal then
        out[#out + 1] = string.char(tonumber(octal, 8))
        i = i + 4
      else
        local escaped = body:sub(i + 1, i + 1)
        out[#out + 1] = self.ESCAPES[escaped] or escaped
        i = i + 2
      end
    end
  end
  return table.concat(out)
end

function GitStatus:read_path(raw, start)
  if raw:sub(start, start) == '"' then
    local i = start + 1
    while i <= #raw do
      local char = raw:sub(i, i)
      if char == '\\' then
        i = i + 2
      elseif char == '"' then
        return self:unescape(raw:sub(start + 1, i - 1)), i + 1
      else
        i = i + 1
      end
    end
    return self:unescape(raw:sub(start + 1)), #raw + 1
  end

  local arrow_pos = raw:find(self.ARROW, start, true)
  if arrow_pos then return raw:sub(start, arrow_pos - 1), arrow_pos end
  return raw:sub(start), #raw + 1
end

function GitStatus:constructor(status)
  local value = status:sub(1, 2)
  local raw_path = status:sub(4, #status)

  local first, second = GitStatus:parse(value)

  local old_filename = nil
  local filename, next_pos = GitStatus:read_path(raw_path, 1)

  if raw_path:sub(next_pos, next_pos + #GitStatus.ARROW - 1) == GitStatus.ARROW then
    old_filename = filename
    filename = GitStatus:read_path(raw_path, next_pos + #GitStatus.ARROW)
  end

  local filetype = fs.detect_filetype(filename)

  return {
    ['$id'] = utils.math.uuid(),
    ['$value'] = value,
    ['$first'] = first,
    ['$second'] = second,
    ['$filename'] = filename,
    ['$old_filename'] = old_filename,
    ['$filetype'] = filetype,
  }
end

function GitStatus:parse(status)
  return status:sub(1, 1), status:sub(2, 2)
end

function GitStatus:has(status)
  local first, second = self:parse(status)
  local actual_first, actual_second = self.first, self.second

  if first == '*' then
    if second == actual_second then return true end
  elseif second == '*' then
    if first == actual_first then return true end
  else
    if first == actual_first and second == actual_second then return true end
  end

  return false
end

function GitStatus:has_either(status)
  local first, second = self:parse(status)
  return first == self.first or second == self.second
end

function GitStatus:has_both(status)
  local first, second = self:parse(status)
  return first == self.first and second == self.second
end

function GitStatus:is_unmerged()
  return utils.list.some({ 'DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU' }, function(status)
    return self:has(status)
  end)
end

function GitStatus:is_staged()
  return utils.list.some({ 'A*', 'M*', 'T*', 'D*', 'R*', 'C*' }, function(status)
    return self:has(status)
  end)
end

function GitStatus:is_unstaged()
  return utils.list.some({ '*M', '*T', '*D', '*R', '*C', '??' }, function(status)
    return self:has(status)
  end)
end

return GitStatus
