local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local Spawn = lazy('vgit.core.Spawn')
local console = lazy('vgit.core.console')
local env = lazy('vgit.core.env')

local gitcli = {}

local _run = event.promisify(function(args, opts, callback)
  local cmd = 'git'

  opts = opts or {}
  local debug = opts.debug

  local effective_args = { '--no-optional-locks', unpack(args) }

  if debug then console.info(cmd .. ' ' .. table.concat(effective_args, ' ')) end

  local err = {}
  local stdout = {}

  local spawn_env = env.get_all()
  if opts.env then
    spawn_env = vim.list_extend(vim.list_extend({}, spawn_env), opts.env)
  end

  Spawn({
    command = cmd,
    args = effective_args,
    env = spawn_env,
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

function gitcli.run(args, opts)
  local result, err, code = _run(args, opts)
  event.await()
  return result, err, code
end

return gitcli
