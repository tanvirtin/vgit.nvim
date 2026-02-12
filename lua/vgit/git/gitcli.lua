local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local Spawn = lazy('vgit.core.Spawn')
local console = lazy('vgit.core.console')
local git_setting = lazy('vgit.settings.git')

local gitcli = {}

local _run = event.promisify(function(args, opts, callback)
  local cmd = 'git'

  opts = opts or {}
  local debug = opts.debug

  if debug then console.info(cmd .. ' ' .. table.concat(args, ' ')) end

  local err = {}
  local stdout = {}

  Spawn({
    command = cmd,
    args = args,
    on_stderr = function(line)
      err[#err + 1] = line
    end,
    on_stdout = function(line)
      stdout[#stdout + 1] = line
    end,
    on_exit = function(code)
      if code == 0 then return callback(stdout, nil, code) end
      if #err ~= 0 then return callback(nil, err, code) end
      callback(stdout, nil, code)
    end,
  }):start()
end, 3)

-- Spawn's on_exit fires in a fast event context where Neovim API calls are
-- forbidden. Schedule back to the main loop so every caller can safely use
-- the Neovim API after a git operation without needing a manual event.await().
function gitcli.run(args, opts)
  local result, err, code = _run(args, opts)
  event.await()
  return result, err, code
end

return gitcli
