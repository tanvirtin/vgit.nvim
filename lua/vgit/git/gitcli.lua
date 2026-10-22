local lazy = require('vgit.core.lazy')

local env = lazy('vgit.core.env')
local Spawn = lazy('vgit.core.Spawn')
local GitTask = lazy('vgit.git.GitTask')
local console = lazy('vgit.core.console')

local gitcli = {}

local function run_git(args, opts)
  opts = opts or {}

  local config_args = {}
  if opts.config then
    for _, entry in ipairs(opts.config) do
      config_args[#config_args + 1] = '-c'
      config_args[#config_args + 1] = entry
    end
  end

  local effective_args = { '--no-optional-locks', '-c', 'core.quotepath=false' }
  vim.list_extend(effective_args, config_args)
  vim.list_extend(effective_args, args)

  local err = {}
  local stdout = {}

  local spawn_env = env.get_all()
  if opts.env then spawn_env = vim.list_extend(vim.list_extend({}, spawn_env), opts.env) end

  local code = vim.async.await(function(done)
    return Spawn({
      command = 'git',
      args = effective_args,
      env = spawn_env,
      stdin = opts.stdin,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_stdout = function(line)
        stdout[#stdout + 1] = line
      end,
      on_exit = function(exit_code)
        done(exit_code)
      end,
    }):start()
  end)

  local cmd_str = 'git ' .. table.concat(effective_args, ' ')
  if code == 0 then
    console.debug.info(cmd_str .. ' (exit=0, ' .. #stdout .. ' lines)')
    return stdout, nil, code
  end
  if #err ~= 0 then
    local log_lines = { cmd_str .. ' (exit=' .. code .. ')' }
    for _, line in ipairs(err) do
      log_lines[#log_lines + 1] = line
    end
    console.debug.error(log_lines)
    return nil, err, code
  end
  return stdout, nil, code
end

gitcli.task = function(args, opts)
  return vim.async
    .run(function()
      return run_git(args, opts)
    end)
    :detach()
end

local function wait_failure(args, reason)
  local cmd = 'git ' .. table.concat(args, ' ')
  return { string.format('git command did not complete (%s): %s', tostring(reason), cmd) }
end

function gitcli.start(args, opts)
  opts = opts or {}

  return GitTask(gitcli.task(args, opts), function(task)
    local ok, result, err, code = task:pwait(opts.timeout)
    if not ok then return nil, wait_failure(args, result), nil end

    return result, err, code
  end)
end

function gitcli.run(args, opts)
  return gitcli.start(args, opts):wait()
end

return gitcli
