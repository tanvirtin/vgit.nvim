local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local GitStatus = Object:extend()

function GitStatus:constructor(filename, value)
  filename = filename:gsub('"', '')

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
  local actual_status = self.value
  local actual_first, actual_second = self.first, self.second

  if actual_first ~= ' ' then
    if first == '*' then return true end
    if first == actual_first then return true end
  end

  if actual_second ~= ' ' then
    if second == '*' then return true end
    if second == actual_second then return true end
  end

  return status == '**' or status == actual_status
end

function GitStatus:has_either(status)
  local first, second = self:parse(status)
  return first == self.first or second == self.second
end

function GitStatus:has_both(status)
  local first, second = self:parse(status)
  return first == self.first and second == self.second
end

function GitStatus:is_ignored()
  return self:has('!!')
end

function GitStatus:is_unchanged()
  return self:has_both('--')
end

function GitStatus:is_staged()
  return self:has('* ')
end

function GitStatus:is_unstaged()
  return self:has(' *')
end

function GitStatus:is_untracked()
  return self:has('??')
end

function GitStatus:is_tracked()
  return not self:is_untracked() and not self:is_ignored()
end

function GitStatus:is_unmerged()
  return self:has_either('UU')
end

return GitStatus
