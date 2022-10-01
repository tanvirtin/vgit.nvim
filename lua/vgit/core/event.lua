local loop = require('vgit.core.loop')

local event = {}

function event.on(event_name, callback)
  vim.api.nvim_create_autocmd(event_name, { callback = loop.async(callback) })

  return event
end

return event
