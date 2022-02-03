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
  local actual_status = self.value
  local actual_first, actual_second = self.first, self.second
  if actual_first ~= ' ' then
    if first == '*' then
      return true
    end
    if first == actual_first then
      return true
    end
  end
  if actual_second ~= ' ' then
    if second == '*' then
      return true
    end
    if second == actual_second then
      return true
    end
  end
  return status == '**' or status == actual_status
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
