local icons = {}

local unavailable = false

function icons.get(fname, extension)
  if unavailable then return nil, '' end

  local has_web_devicons, web_devicons = pcall(require, 'nvim-web-devicons')
  if not has_web_devicons then
    unavailable = true
    return nil, ''
  end

  if not web_devicons.has_loaded() then return nil, '' end
  return web_devicons.get_icon(fname, extension)
end

return icons
