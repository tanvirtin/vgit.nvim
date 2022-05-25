local object = {}

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

function object.merge(...)
  local o = {}
  local objects = { ... }

  for i = 1, #objects do
    o = vim.tbl_deep_extend('force', o, objects[i])
  end

  return o
end

function object.pairs(o)
  local pairs = {}

  for key, component in pairs(o) do
    pairs[#pairs + 1] = { key, component }
  end

  return pairs
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

function object.clone_deep(config_object)
  return vim.tbl_deep_extend('force', {}, config_object)
end

function object.clone(config_object)
  return vim.tbl_extend('force', {}, config_object)
end

function object.each(o, callback)
  for key, value in pairs(o) do
    local break_loop = callback(value, key)

    if break_loop then
      return
    end
  end
end

object.is_empty = vim.tbl_isempty

return object
