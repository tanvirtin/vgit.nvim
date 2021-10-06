local M = {
  buf = {},
  namespace = 'VGit',
}

M.setup = function()
  vim.cmd(string.format('aug %s | autocmd! | aug END', M.namespace))
end

M.off = function()
  vim.cmd(string.format('aug %s | autocmd! | aug END', M.namespace))
end

M.on = function(cmd, handler, options)
  local once = (options and options.once) or false
  local override = (options and options.override) or true
  local nested = (options and options.nested) or false
  vim.api.nvim_exec(
    string.format(
      'au%s %s %s * %s %s %s',
      override and '!' or '',
      M.namespace,
      cmd,
      nested and '++nested' or '',
      once and '++once' or '',
      handler
    ),
    false
  )
end

M.buf.on = function(buf, cmd, handler, options)
  local once = (options and options.once) or false
  local override = (options and options.override) or true
  local nested = (options and options.nested) or false
  vim.api.nvim_exec(
    string.format(
      'au%s %s %s <buffer=%s> %s %s %s',
      override and '!' or '',
      M.namespace,
      cmd,
      buf,
      nested and '++nested' or '',
      once and '++once' or '',
      handler
    ),
    false
  )
end

M.buf.off = function(buf, cmd)
  vim.api.nvim_exec(
    string.format('au! %s %s <buffer=%s> ++once ', M.namespace, cmd, buf),
    false
  )
end

return M
