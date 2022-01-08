local has_web_devicons, web_devicons = pcall(require, 'nvim-web-devicons')

local icons = {}

icons.file_icon = function(fname, extension)
  if not has_web_devicons or not web_devicons.has_loaded() then
    return nil, ''
  end
  return web_devicons.get_icon(fname, extension)
end

return icons
