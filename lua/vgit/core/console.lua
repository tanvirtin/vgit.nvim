local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local env = require('vgit.core.env')

local console = {}

local function add_vgit_prefix(msg)
  return string.format('[VGit] %s', msg)
end

local function add_indentiation(msg)
  return string.format('       %s', msg)
end

local function vgit_stringify(msg)
  if type(msg) ~= 'table' then
    return add_vgit_prefix(msg)
  end
  return utils.list.reduce(msg, '', function(acc, line, i)
    if i == 1 then
      acc = string.format('%s%s\n', acc, add_vgit_prefix(line))
    elseif i ~= #msg then
      acc = string.format('%s%s\n', acc, add_indentiation(line))
    else
      acc = string.format('%s%s', acc, add_indentiation(line))
    end
    return acc
  end)
end

local function log_msg(msg, hi)
  vim.api.nvim_echo({ { vgit_stringify(msg), hi } }, false, {})
end

console.error = loop.async(function(msg)
  loop.await_fast_event()
  log_msg(msg, 'ErrorMsg')
end)

console.warn = loop.async(function(msg)
  loop.await_fast_event()
  log_msg(msg, 'WarningMsg')
end)

console.log = loop.async(function(msg)
  loop.await_fast_event()
  log_msg(msg)
end)

console.clear = loop.async(function()
  loop.await_fast_event()
  vim.cmd('echo ""')
end)

console.info = loop.async(function(msg)
  loop.await_fast_event()
  vim.notify(msg, 'info')
end)

console.input = function(prompt)
  local result = vim.fn.input(prompt)
  console.clear()
  return result
end

console.debug = loop.async(function(msg, trace)
  if not env.get('DEBUG') then
    return
  end
  local new_msg = ''
  if vim.tbl_islist(msg) then
    for i = 1, #msg do
      local m = msg[i]
      if i == 1 then
        new_msg = new_msg .. m
      else
        new_msg = new_msg .. ', ' .. m
      end
    end
  else
    new_msg = msg
  end
  local log = ''
  if trace then
    log = string.format('[%s] %s\n%s', os.date('%H:%M:%S'), new_msg, trace)
  else
    log = string.format('[%s] %s', os.date('%H:%M:%S'), new_msg)
  end
  print(vgit_stringify(log))
end)

return console
