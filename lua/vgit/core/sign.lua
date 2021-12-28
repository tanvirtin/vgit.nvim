local signs_setting = require('vgit.settings.signs')

local sign = {}

sign.define = function(name, config)
  vim.fn.sign_define(name, {
    text = config.text,
    texthl = config.texthl,
    numhl = config.numhl,
    icon = config.icon,
    linehl = config.linehl,
  })
end

sign.register_module = function(dependency)
  for name, config in pairs(signs_setting:get('definitions')) do
    sign.define(name, config)
  end
  if dependency then
    dependency()
  end
end

return sign
