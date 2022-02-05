local Object = require('vgit.core.Object')
local ListControl = Object:extend()

function ListControl:new()
  return setmetatable({
    last = 1,
    current = 1,
  }, ListControl)
end

function ListControl:is_unchanged()
  return self.last == self.current
end

function ListControl:is_changed()
  return self.last ~= self.current
end

function ListControl:sync(source, direction)
  local lnum = source:get_lnum()
  self.last = self.current
  if direction == 'up' then
    lnum = lnum - 1
  elseif direction == 'down' then
    lnum = lnum + 1
  end
  local total_line_count = source:get_line_count()
  if lnum > total_line_count then
    lnum = 1
  elseif lnum < 1 then
    lnum = total_line_count
  end
  self.current = lnum
  return self
end

function ListControl:set_i(i)
  self.last = self.current
  self.current = i
  return self
end

function ListControl:i()
  return self.current
end

function ListControl:i_1()
  return self.last
end

function ListControl:resync()
  self.last = 1
  self.current = 1
end

return ListControl
