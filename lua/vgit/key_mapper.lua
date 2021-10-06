local M = {}

local function set_keymap(mode, key, action)
  vim.api.nvim_set_keymap(mode, key, action, {
    noremap = true,
    silent = true,
  })
end

local function parse_commands(commands)
  local parsed_commands = vim.split(commands, ' ')
  for i = 1, #parsed_commands do
    local c = parsed_commands[i]
    parsed_commands[i] = vim.trim(c)
  end
  return parsed_commands
end

M.setup = function(config)
  config = config or {}
  local keymaps = config.keymaps or {}
  for commands, action in pairs(keymaps) do
    commands = parse_commands(commands)
    set_keymap(commands[1], commands[2], string.format(':VGit %s<CR>', action))
  end
end

return M
