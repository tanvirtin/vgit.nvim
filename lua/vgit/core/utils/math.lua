local M = {}

function M.round(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

function M.uuid()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)

    return string.format('%x', v)
  end)
end

function M.scale_unit_up(unit, percent)
  return math.floor(unit * (100 + percent) / 100)
end

function M.scale_unit_down(unit, percent)
  unit = math.floor(unit * (100 - percent) / 100)

  if unit < 1 then
    unit = 1
  end

  return unit
end

return M
