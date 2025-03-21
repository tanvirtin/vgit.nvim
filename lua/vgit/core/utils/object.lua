local object = {}

object.is_empty = vim.tbl_isempty

function object.first(o)
  o = o or {}

  for _, value in pairs(o) do
    return value
  end

  return nil
end

function object.size(o)
  o = o or {}
  local count = 0

  for _ in pairs(o) do
    count = count + 1
  end

  return count
end

function object.defaults(o, ...)
  o = o or {}
  local objects = { ... }

  for i = 1, #objects do
    o = vim.tbl_deep_extend('keep', o, objects[i])
  end

  return o
end

function object.assign(o, ...)
  o = o or {}
  local objects = { ... }

  for i = 1, #objects do
    o = vim.tbl_deep_extend('force', o, objects[i])
  end

  return o
end

function object.pick(o, keys)
  o = o or {}
  local picked_o = {}

  object.each(o, function(value, key)
    for i = 1, #keys do
      local k = keys[i]
      if k == key then picked_o[key] = value end
    end
  end)

  return picked_o
end

function object.extend(o, ...)
  o = o or {}
  local objects = { ... }

  for i = 1, #objects do
    o = vim.tbl_extend('force', o, objects[i])
  end

  return o
end

function object.merge(...)
  local o = {}
  local objects = { ... }

  for i = 1, #objects do
    o = vim.tbl_deep_extend('force', o, objects[i])
  end

  return o
end

function object.pairs(o)
  local p = {}

  for key, component in pairs(o) do
    p[#p + 1] = { key, component }
  end

  return p
end

function object.keys(o)
  local keys = {}

  for key, _ in pairs(o) do
    keys[#keys + 1] = key
  end

  return keys
end

function object.values(o)
  local values = {}

  for _, value in pairs(o) do
    values[#values + 1] = value
  end

  return values
end

function object.deep_clone(o)
  return vim.deepcopy(o, true)
end

function object.clone(config_object)
  return vim.tbl_extend('force', {}, config_object)
end

function object.each(o, callback)
  for key, value in pairs(o) do
    local break_loop = callback(value, key)
    if break_loop then return end
  end
end

return object
