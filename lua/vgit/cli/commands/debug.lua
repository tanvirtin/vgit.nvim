local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')

local debug_command = {}

debug_command.execute = event.async(function(args)
  event.await()

  local subcommand = args and args[1]

  if subcommand == 'on' then
    console.debug.enable()
    console.info('Debug mode enabled')
    return
  end

  if subcommand == 'off' then
    console.debug.disable()
    console.info('Debug mode disabled')
    return
  end

  if subcommand == 'status' then
    if console.debug.is_enabled() then
      console.info('Debug mode is enabled')
    else
      console.info('Debug mode is disabled')
    end
    return
  end

  if subcommand == 'open' then
    console.debug.open()
    return
  end
end)

return debug_command
