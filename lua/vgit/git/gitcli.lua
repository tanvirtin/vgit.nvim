local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local Spawn = lazy('vgit.core.Spawn')
local console = lazy('vgit.core.console')
local env = lazy('vgit.core.env')

local gitcli = {}

local _run = event.promisify(function(args, opts, callback)
  local cmd = 'git'

  opts = opts or {}

  local config_args = {}
  if opts.config then
    for _, entry in ipairs(opts.config) do
      config_args[#config_args + 1] = '-c'
      config_args[#config_args + 1] = entry
    end
  end

  local effective_args = { '--no-optional-locks' }
  vim.list_extend(effective_args, config_args)
  vim.list_extend(effective_args, args)

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
      local cmd_str = 'git ' .. table.concat(effective_args, ' ')
      if code == 0 then
        console.debug.info(cmd_str .. ' (exit=0, ' .. #stdout .. ' lines)')
        return callback(stdout, nil, code)
      end
      if #err ~= 0 then
        local log_lines = { cmd_str .. ' (exit=' .. code .. ')' }
        for _, line in ipairs(err) do log_lines[#log_lines + 1] = line end
        console.debug.error(log_lines)
        return callback(nil, err, code)
      end
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
