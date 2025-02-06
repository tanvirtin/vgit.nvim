local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Rgb = Object:extend()

function Rgb:constructor(hex)
  local color

  if hex then color = hex:gsub('#', '') end

  return {
    hex = hex,
    r = hex and tonumber(color:sub(1, 2), 16) or nil,
    g = hex and tonumber(color:sub(3, 4), 16) or nil,
    b = hex and tonumber(color:sub(5), 16) or nil,
  }
end

function Rgb:scale_up(percent)
  if not self.hex then return self end

  self.r, self.g, self.b =
    utils.math.scale_unit_up(self.r, percent),
    utils.math.scale_unit_up(self.g, percent),
    utils.math.scale_unit_up(self.b, percent)

  return self
end

function Rgb:scale_down(percent)
  if not self.hex then return self end

  self.r, self.g, self.b =
    utils.math.scale_unit_down(self.r, percent),
    utils.math.scale_unit_down(self.g, percent),
    utils.math.scale_unit_down(self.b, percent)

  return self
end

function Rgb:get()
  if not self.hex then return 'NONE' end

  local r, g, b = self.r, self.g, self.b

  r, g, b = math.min(r, 255), math.min(g, 255), math.min(b, 255)

  return string.format('#%02x%02x%02x', r, g, b)
end

return Rgb
