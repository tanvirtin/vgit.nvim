local Object = require('vgit.core.Object')

local Status = Object:extend()

function Status:new(value)
  local first, second = Status:parse(value)
  return setmetatable({
    value = value,
    first = first,
    second = second,
  }, Status)
end

function Status:parse(status)
  return status:sub(1, 1), status:sub(2, 2)
end

function Status:has(status)
  local first, second = self:parse(status)
  if self.first ~= ' ' then
    return self.first == first
  end
  if self.second ~= ' ' then
    return self.second == second
  end
  return self.value == status
end

function Status:has_either(status)
  local first, second = self:parse(status)
  return first == self.first or second == self.second
end

function Status:has_both(status)
  local first, second = self:parse(status)
  return first == self.first and second == self.second
end

function Status:to_string()
  return self.value
end

return Status
