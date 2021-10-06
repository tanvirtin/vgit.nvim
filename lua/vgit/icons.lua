local M = {}

M.file_icon = function(fname, extension)
  local ok, web_devicons = pcall(require, 'nvim-web-devicons')
  if not ok then
    return ' ', nil
  end
  return web_devicons.get_icon(fname, extension)
end

return M
