local Interface = require('vgit.Interface')

local M = {}

M.state = Interface:new({
  current = {},
})

M.get = function()
  return M.state:get('current')
end

M.set = function(component)
  assert(type(component) == 'table', 'type error :: expected table')
  M.state:set('current', component)
end

M.exists = function()
  return not vim.tbl_isempty(M.get())
end

M.clear = function()
  if M.exists() then
    M.get():unmount()
    M.state:set('current', {})
  end
end

return M
