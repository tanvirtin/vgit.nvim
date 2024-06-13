local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local GitStatus = Object:extend()

function GitStatus:constructor(status)
  local value = status:sub(1, 2)
  local filename = status:sub(4, #status):gsub('"', '')

  local first, second = GitStatus:parse(value)
  local filetype = fs.detect_filetype(filename)

  return {
    id = utils.math.uuid(),
    value = value,
    first = first,
    second = second,
    filename = filename,
    filetype = filetype,
  }
end

function GitStatus:parse(status)
  return status:sub(1, 1), status:sub(2, 2)
end

function GitStatus:has(status)
  local first, second = self:parse(status)
  local actual_first, actual_second = self.first, self.second

  if first == '*' then
    if second == actual_second then
      return true
    end
  elseif second == '*' then
    if first == actual_first then
      return true
    end
  else
    if first == actual_first and second == actual_second then
      return true
    end
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
  return utils.list.some({ 'DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU' }, function (status)
    return self:has(status)
  end)
end

function GitStatus:is_staged()
  return utils.list.some({ 'A*', 'M*', 'T*', 'D*', 'R*', 'C*' }, function (status)
    return self:has(status)
  end)
end

function GitStatus:is_unstaged()
  return utils.list.some({ '*M', '*T', '*D', '*R', '*C', '??' }, function (status)
    return self:has(status)
  end)
end

return GitStatus
