local renderer = {
  registered = false,
  buffers = {},
}

local namespace = vim.api.nvim_create_namespace('vgit')

function renderer.register_module()
  if renderer.registered then
    return
  end
  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, _, bufnr, top, bot)
      local buffer = renderer.buffers[bufnr]
      if buffer and bufnr == buffer.bufnr then
        buffer:on_render(top, bot)
      end
      return false
    end,
  })
  renderer.registered = true
end

function renderer.attach(buffer)
  renderer.buffers[buffer.bufnr] = buffer
end

function renderer.detach(buffer)
  renderer.buffers[buffer.bufnr] = nil
end

return renderer
