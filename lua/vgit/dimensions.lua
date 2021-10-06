local M = {}

M.global_width = function()
  return vim.o.columns
end

M.global_height = function()
  return vim.o.lines
end

M.calculate_text_center = function(text, width)
  local rep = math.floor((width / 2) - math.floor(#text / 2))
  return (rep < 0 and 0) or rep
end

return M
