local loop = require('vgit.core.loop')
local Spawn = require('vgit.core.Spawn')
local console = require('vgit.core.console')
local git_setting = require('vgit.settings.git')

local gitcli = {}

gitcli.run = loop.suspend(function(args, opts, callback)
  local cmd = git_setting:get('cmd')

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
    on_exit = function()
      if #err ~= 0 then return callback(nil, err) end
      callback(stdout, nil)
    end,
  }):start()
end, 3)

return gitcli
