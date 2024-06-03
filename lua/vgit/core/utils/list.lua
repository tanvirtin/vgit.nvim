local list = {}

list.is_list = vim.tbl_islist

list.is_empty = vim.tbl_isempty

function list.join(l, with)
  local result = ''

  for i = 1, #l do
    result = result .. l[i] .. with
  end

  return result
end

function list.pick(l, item)
  for i = 1, #l do
    if l[i] == item then return item end
  end

  return l[1]
end

function list.concat(a, b)
  for i = 1, #b do
    a[#a + 1] = b[i]
  end

  return a
end

function list.merge(t, ...)
  local a = vim.deepcopy(t)
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

return list
