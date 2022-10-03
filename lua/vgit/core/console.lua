local env = require('vgit.core.env')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')

local console = {
  debug = {
    source = {
      infos = {},
      errors = {},
      warnings = {},
    },
  },
}

function console.format(msg)
  local function add_vgit_prefix(line) return string.format('[VGit] %s', line) end

  local function add_indentiation(line) return string.format('       %s', line) end

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

console.log = loop.async(function(msg, hi)
  loop.await()
  vim.api.nvim_echo({ { console.format(msg), hi } }, false, {})

  return console
end)

console.error = loop.async(function(msg)
  console.log(msg, 'ErrorMsg')

  return console
end)

console.warn = loop.async(function(msg)
  console.log(msg, 'WarningMsg')

  return console
end)

console.clear = loop.async(function()
  loop.await()
  vim.cmd('echo ""')

  return console
end)

console.info = loop.async(function(msg)
  loop.await()
  vim.notify(msg, 'info')

  return console
end)

console.input = function(prompt)
  local result = vim.fn.input(prompt)
  console.clear()

  return result
end

function console.debug.get_source_logger(source)
  return function(msg)
    if not env.get('DEBUG') then
      return console
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

    local debug_info = debug.getinfo(2)

    source[#source + 1] = console.format(
      string.format(
        '[time:%s] [source:%s] [func:%s] %s',
        os.date('%H:%M:%S'),
        debug_info.source,
        debug_info.name,
        new_msg
      )
    )

    return console
  end
end

console.debug.info = console.debug.get_source_logger(console.debug.source.infos)

console.debug.error = console.debug.get_source_logger(console.debug.source.errors)

console.debug.warning = console.debug.get_source_logger(console.debug.source.warnings)

return console
