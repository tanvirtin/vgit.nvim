local str = {}

local function pesc(value)
  return (value:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1'))
end

local function split(s, sep, opts)
  if vim and vim.split then return vim.split(s, sep, opts) end

  opts = opts or {}

  local plain = opts.plain
  local keepempty = opts.keepempty
  local trimempty = opts.trimempty
  local result = {}

  if sep == '' then
    for i = 1, #s do
      result[#result + 1] = s:sub(i, i)
    end
    return result
  end

  local pattern = plain and pesc(sep) or sep
  local start = 1

  while true do
    local a, b = s:find(pattern, start)
    if not a then break end

    local piece = s:sub(start, a - 1)

    if piece ~= '' or keepempty then
      if not (trimempty and piece:match('^%s*$')) then result[#result + 1] = piece end
    end

    start = b + 1
    if b < a then start = a + 1 end
  end

  local last = s:sub(start)

  if last ~= '' or keepempty then
    if not (trimempty and last:match('^%s*$')) then result[#result + 1] = last end
  end

  return result
end

str.split = split

function str.length(s)
  local _, count = string.gsub(s, '[^\128-\193]', '')

  return count
end

function str.shorten(s, limit)
  if #s > limit then
    s = s:sub(1, limit - 3)
    s = s .. '...'
  end

  return s
end

function str.concat(existing_text, new_text)
  local top_range = #existing_text
  local end_range = top_range + #new_text
  local text = existing_text .. new_text

  return text, {
    top = top_range,
    bot = end_range,
  }
end

function str.strip(given_string, substring)
  if substring == '' then return given_string end

  return (given_string:gsub(pesc(substring), '', 1))
end

return str
