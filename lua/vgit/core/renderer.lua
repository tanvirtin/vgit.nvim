local Namespace = require('vgit.core.Namespace')

local renderer = {
  registered = false,
  buffers = {},
}

local namespace = Namespace('vgit')

function renderer.register_module()
  if renderer.registered then
    return renderer
  end

  vim.api.nvim_set_decoration_provider(namespace.ns_id, {
    on_win = function(_, _, bufnr, top, bot)
      local buffer = renderer.buffers[bufnr]
      if buffer and bufnr == buffer.bufnr then
        buffer:on_render(top, bot)
      end
      return false
    end,
  })

  renderer.registered = true

  return renderer
end

function renderer.attach(buffer)
  renderer.buffers[buffer.bufnr] = buffer

  return renderer
end

function renderer.detach(buffer)
  renderer.buffers[buffer.bufnr] = nil

  return renderer
end

return renderer
