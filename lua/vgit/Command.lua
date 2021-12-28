local console = require('vgit.core.console')
local Object = require('vgit.core.Object')

local Command = Object:extend()

function Command:new()
  return setmetatable({}, Command)
end

function Command:execute(command, ...)
  local vgit = require('vgit')
  if not command then
    return
  end
  local starts_with = command:sub(1, 1)
  if
    starts_with == '_'
    or not vgit[command]
    or not type(vgit[command]) == 'function'
  then
    console.error(string.format('Invalid VGit command %s', command))
    return
  end
  return vgit[command](...)
end

function Command:list(arglead, line)
  local vgit = require('vgit')
  local parsed_line = #vim.split(line, '%s+')
  local matches = {}
  if parsed_line == 2 then
    for name, func in pairs(vgit) do
      if
        not vim.startswith(name, '_')
        and vim.startswith(name, arglead)
        and type(func) == 'function'
      then
        matches[#matches + 1] = name
      end
    end
  end
  return matches
end

return Command
