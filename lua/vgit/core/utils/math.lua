local M = {}

function M.round(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

function M.uuid()
  return require('vgit.vendor.jit-uuid').generate_v4()
end

function M.scale_unit_up(unit, percent)
  return math.floor(unit * (100 + percent) / 100)
end

function M.scale_unit_down(unit, percent)
  unit = math.floor(unit * (100 - percent) / 100)

  if unit < 1 then return 1 end
  return unit
end

return M
