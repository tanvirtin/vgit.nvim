local signs_setting = require('vgit.settings.signs')

local sign = {}

function sign.define(name, config)
  vim.fn.sign_define(name, {
    text = config.text,
    texthl = config.texthl,
    numhl = config.numhl,
    icon = config.icon,
    linehl = config.linehl,
  })

  return sign
end

function sign.register_module(dependency)
  for name, config in pairs(signs_setting:get('definitions')) do
    sign.define(name, config)
  end

  if dependency then dependency() end

  return sign
end

return sign
