local state = {
  namespace = 'VGit',
}

local autocmd = {}

autocmd.register_module = function(dependency)
  vim.api.nvim_exec(
    string.format('aug %s | autocmd! | aug END', state.namespace),
    false
  )
  if dependency then
    dependency()
  end
end

autocmd.off = function()
  vim.api.nvim_exec(
    string.format('aug %s | autocmd! | aug END', state.namespace),
    false
  )
end

autocmd.on = function(cmd, handler, options)
  options = options or {}
  if options.once == nil then
    options.once = false
  end
  if options.override == nil then
    options.override = true
  end
  if options.nested == nil then
    options.nested = false
  end
  vim.api.nvim_exec(
    string.format(
      'au%s %s %s * %s %s :lua _G.package.loaded.vgit.%s',
      options.override and '!' or '',
      state.namespace,
      cmd,
      options.nested and '++nested' or '',
      options.once and '++once' or '',
      handler
    ),
    false
  )
end

return autocmd
