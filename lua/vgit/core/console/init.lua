local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local LogFormatter = lazy('vgit.core.console.LogFormatter')

local console = {}

console.debug = lazy('vgit.core.console.debug_logger')

function console.format(msg)
  return LogFormatter(msg, { timestamp = false }):format():value()
end

console.error = event.async(function(msg)
  event.await()
  msg = console.format(msg)
  vim.notify(msg, vim.log.levels.ERROR)

  return console
end)

console.warn = event.async(function(msg)
  event.await()
  msg = console.format(msg)
  vim.notify(msg, vim.log.levels.WARN)

  return console
end)

console.clear = event.async(function()
  event.await()
  vim.cmd('echo ""')

  return console
end)

console.info = event.async(function(msg)
  event.await()
  msg = console.format(msg)
  vim.notify(msg, vim.log.levels.INFO)

  return console
end)

console.input = function(prompt)
  local ok, result = pcall(vim.fn.input, prompt)
  console.clear()

  if not ok then return nil end

  return result
end

console.cleanup = event.async(function()
  console.debug.cleanup()
  return console
end)

return console
