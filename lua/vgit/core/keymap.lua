local keymap = {}

local function parse_commands(commands)
  local parsed_commands = vim.split(commands, ' ')
  for i = 1, #parsed_commands do
    local c = parsed_commands[i]
    parsed_commands[i] = vim.trim(c)
  end
  return parsed_commands
end

function keymap.set(mode, key, action)
  vim.api.nvim_set_keymap(
    mode,
    key,
    string.format('<Cmd>lua require("vgit").%s()<CR>', action),
    {
      noremap = true,
      silent = true,
    }
  )
end

function keymap.buffer_set(buffer, mode, key, action)
  vim.api.nvim_buf_set_keymap(
    buffer.bufnr,
    mode,
    key,
    string.format('<Cmd>lua require("vgit").%s()<CR>', action),
    {
      silent = true,
      noremap = true,
    }
  )
end

function keymap.define(keymaps)
  for commands, action in pairs(keymaps) do
    commands = parse_commands(commands)
    keymap.set(commands[1], commands[2], action)
  end
end

return keymap
