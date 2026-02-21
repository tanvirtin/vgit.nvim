local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local Spawn = lazy('vgit.core.Spawn')
local console = lazy('vgit.core.console')

local gitcli = {}

local _env = (function()
  local env = {}

  for k, v in pairs(vim.fn.environ()) do
    env[#env + 1] = string.format('%s=%s', k, v)
  end
  env[#env + 1] = 'LC_ALL=C'
  env[#env + 1] = 'LANGUAGE=C'

  return env
end)()

local _run = event.promisify(function(args, opts, callback)
  local cmd = 'git'

  opts = opts or {}
  local debug = opts.debug

  local effective_args = { '--no-optional-locks', unpack(args) }

  if debug then console.info(cmd .. ' ' .. table.concat(effective_args, ' ')) end

  local err = {}
  local stdout = {}

  local env = _env
  if opts.env then
    env = vim.list_extend(vim.list_extend({}, _env), opts.env)
  end

  Spawn({
    command = cmd,
    args = effective_args,
    env = env,
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
