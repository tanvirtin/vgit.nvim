local list = {}

local function is_list(value)
  if type(value) ~= 'table' then return false end

  local count = 0

  for key in pairs(value) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return false end
    count = count + 1
  end

  return count == #value
end

local function is_empty(value)
  return next(value) == nil
end

local function deep_clone(value)
  if type(value) ~= 'table' then return value end

  local out = {}

  for k, v in pairs(value) do
    out[k] = deep_clone(v)
  end

  return out
end

list.is_list = is_list

list.is_empty = is_empty

function list.join(l, with)
  local result = ''

  for i = 1, #l do
    result = result .. l[i]
    if i ~= #l then result = result .. with end
  end

  return result
end

function list.pick(l, item)
  for i = 1, #l do
    if l[i] == item then return item end
  end

  return l[1]
end

function list.concat(a, ...)
  local lists = { ... }

  for i = 1, #lists do
    local b = lists[i]
    for j = 1, #b do
      a[#a + 1] = b[j]
    end
  end

  return a
end

function list.merge(t, ...)
  local a = deep_clone(t)
  local lists = { ... }

  for i = 1, #lists do
    local b = lists[i]

    for _, value in ipairs(b) do
      a[#a + 1] = value
    end
  end

  return a
end

function list.map(l, callback)
  local new_list = {}

  for i = 1, #l do
    new_list[#new_list + 1] = callback(l[i], i)
  end

  return new_list
end

function list.filter(l, callback)
  local new_list = {}

  for i = 1, #l do
    local list_item = l[i]
    local result = callback(list_item, i)

    if result then new_list[#new_list + 1] = list_item end
  end

  return new_list
end

function list.each(l, callback)
  for i = 1, #l do
    local break_loop = callback(l[i], i)
    if break_loop then return end
  end
end

function list.reduce(l, accumulator, callback)
  for i = 1, #l do
    accumulator = callback(accumulator, l[i], i)
  end

  return accumulator
end

function list.find(l, callback)
  for i = 1, #l do
    local item = l[i]
    local found = callback(item, i)

    if found then return item end
  end
end

function list.replace(l, startIndex, endIndex, replacementItems)
  for i = endIndex, startIndex, -1 do
    table.remove(l, i)
  end
  for i, item in ipairs(replacementItems) do
    table.insert(l, startIndex + i - 1, item)
  end
  return l
end

function list.extract(l, startIndex, endIndex)
  local extractedItems = {}
  for i = startIndex, endIndex do
    table.insert(extractedItems, l[i])
  end
  return extractedItems
end

function list.some(l, callback)
  for i = 1, #l do
    local item = l[i]
    local has_some = callback(item, i)

    if has_some == true then return true end
  end

  return false
end

return list
