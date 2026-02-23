local lazy = require('vgit.core.lazy')
local console = lazy('vgit.core.console')

local router = {}

local COMMAND_MAP = {
  diff = 'vgit.cli.commands.diff',
  blame = 'vgit.cli.commands.blame',
  hunk = 'vgit.cli.commands.hunk',
  status = 'vgit.cli.commands.status',
  show = 'vgit.cli.commands.show',
  branch = 'vgit.cli.commands.branch',
  log = 'vgit.cli.commands.log',
  debug = 'vgit.cli.commands.debug',
}

function router.execute(args)
  if not args or #args == 0 then
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
    console.error('Unknown command: ' .. command)
    return
  end

  local ok, handler = pcall(require, handler_module)
  if not ok or not handler or type(handler.execute) ~= 'function' then
    console.error('Failed to load command: ' .. command)
    return
  end

  handler.execute(command_args)
end

return router
