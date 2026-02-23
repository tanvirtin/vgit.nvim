local value = {}

function value.is_nil(v)
  return v == nil
end

function value.exists(v)
  return not value.is_nil(v)
end

function value.default(v, fallback)
  if value.is_nil(v) then v = fallback end
  return v
end

return value
