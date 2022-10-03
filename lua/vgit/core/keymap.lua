local keymap = {}

local function parse_commands(commands)
  local parsed_commands = vim.split(commands, ' ')

  for i = 1, #parsed_commands do
    local c = parsed_commands[i]

    parsed_commands[i] = vim.trim(c)
  end

  return parsed_commands
end

function keymap.set(mode, key, callback)
  if type(callback) == 'string' then
    vim.api.nvim_set_keymap(mode, key, string.format('<Cmd>lua require("vgit").%s()<CR>', callback), {
      noremap = true,
      silent = true,
    })

    return keymap
  end

  vim.keymap.set(mode, key, callback, { silent = true, noremap = true })

  return keymap
end

function keymap.buffer_set(buffer, mode, key, callback)
  vim.keymap.set(mode, key, callback, { buffer = buffer.bufnr, silent = true, noremap = true })

  return keymap
end

function keymap.define(keymaps)
  for commands, callback in pairs(keymaps) do
    commands = parse_commands(commands)
    keymap.set(commands[1], commands[2], callback)
  end

  return keymap
end

return keymap
