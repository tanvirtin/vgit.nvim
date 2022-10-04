local Rgb = require('vgit.core.Rgb')
local bit = require('vgit.vendor.bit')
local Object = require('vgit.core.Object')

local Color = Object:extend()

function Color:constructor(spec)
  return {
    spec = spec,
    rgb = nil,
    hex = nil,
  }
end

function Color:to_hex()
  if self.hex then
    return self.hex
  end

  local spec = self.spec
  local attribute = spec.attribute == 'fg' and 'foreground' or 'background'
  local success, hl = pcall(vim.api.nvim_get_hl_by_name, spec.name, true)

  if success and hl and hl[attribute] then
    self.hex = '#' .. bit.tohex(hl[attribute], 6)
  end

  return self.hex
end

function Color:to_rgb()
  self.rgb = self.rgb or Rgb(self:to_hex())

  return self.rgb
end

function Color:get() return self:to_rgb():get() end

function Color:lighten(percent)
  self:to_rgb():scale_up(percent)

  return self
end

function Color:darken(percent)
  self:to_rgb():scale_down(percent)

  return self
end

return Color
