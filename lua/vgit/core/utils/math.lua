local M = {}

function M.round(x)
  return math.floor(x)
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

  if unit < 1 then return 1 end
  return unit
end

return M
