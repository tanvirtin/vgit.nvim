local renderer = {
  registered = false,
  buffers = {},
  ns_id = nil,
}

local function ensure_ns_id()
  if renderer.ns_id then return renderer.ns_id end
  renderer.ns_id = vim.api.nvim_create_namespace('vgit')
  return renderer.ns_id
end

function renderer.register_module()
  if renderer.registered then return renderer end

  ensure_ns_id()
  vim.api.nvim_set_decoration_provider(renderer.ns_id, {
    on_win = function(_, _, bufnr, top, bot)
      local buffer = renderer.buffers[bufnr]
      if buffer and bufnr == buffer.bufnr then buffer:render(top, bot) end
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

function renderer.reset()
  renderer.registered = false
  renderer.buffers = {}
  renderer.ns_id = nil
end

return renderer
