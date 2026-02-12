local lazy = require('vgit.core.lazy')
local bit = lazy('vgit.vendor.bit')
local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')

local Color = Object:extend()

function Color:constructor(spec)
  if not spec then error('spec is required') end
  if not spec.name then error('spec.name is required') end
  if not spec.attribute then error('spec.attribute is required') end

  return {
    spec = spec,
    hex = nil,
    r = nil,
    g = nil,
    b = nil,
  }
end

function Color:to_hex()
  if self.hex then return self.hex end

  local spec = self.spec
  local attribute = spec.attribute == 'fg' and 'foreground' or 'background'
  local success, hl = pcall(vim.api.nvim_get_hl_by_name, spec.name, true)

  if success and hl and hl[attribute] then self.hex = '#' .. bit.tohex(hl[attribute], 6) end

  if self.hex then
    local color = self.hex:gsub('#', '')
    self.r = tonumber(color:sub(1, 2), 16)
    self.g = tonumber(color:sub(3, 4), 16)
    self.b = tonumber(color:sub(5), 16)
  end

  return self.hex
end

function Color:get()
  if not self:to_hex() then return 'NONE' end

  local r, g, b = self.r, self.g, self.b
  r, g, b = math.min(r, 255), math.min(g, 255), math.min(b, 255)

  return string.format('#%02x%02x%02x', r, g, b)
end

function Color:lighten(percent)
  self:to_hex()
  if not self.hex then return self end

  self.r = utils.math.scale_unit_up(self.r, percent)
  self.g = utils.math.scale_unit_up(self.g, percent)
  self.b = utils.math.scale_unit_up(self.b, percent)

  return self
end

function Color:darken(percent)
  self:to_hex()
  if not self.hex then return self end

  self.r = utils.math.scale_unit_down(self.r, percent)
  self.g = utils.math.scale_unit_down(self.g, percent)
  self.b = utils.math.scale_unit_down(self.b, percent)

  return self
end

function Color:to_rgb()
  self:to_hex()
  if not self.hex then return nil end

  return {
    hex = self.hex,
    r = self.r,
    g = self.g,
    b = self.b,
  }
end

return Color
