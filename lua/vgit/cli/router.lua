local router = {}

local COMMAND_MAP = {
  diff = 'vgit.cli.commands.diff',
  blame = 'vgit.cli.commands.blame',
  hunk = 'vgit.cli.commands.hunk',
}

function router.execute(args)
  if not args or #args == 0 then
    local console = require('vgit.core.console')
    console.error('No command provided')
    return
  end

  local command = args[1]
  local command_args = {}
  for i = 2, #args do
    table.insert(command_args, args[i])
  end

  local handler_module = COMMAND_MAP[command]
  if not handler_module then
    local console = require('vgit.core.console')
    console.error('Unknown command: ' .. command)
    return
  end

  local ok, handler = pcall(require, handler_module)
  if not ok then
    local console = require('vgit.core.console')
    console.error('Failed to load command handler: ' .. command)
    return
  end

  handler.execute(command_args)
end

return router
