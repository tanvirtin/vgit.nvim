local str = {}

str.split = vim.split

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

  return (given_string:gsub(vim.pesc(substring), '', 1))
end

return str
