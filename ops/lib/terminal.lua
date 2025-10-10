local M = {}

M.colors = {
  red = '\27[0;31m',
  green = '\27[0;32m',
  yellow = '\27[1;33m',
  blue = '\27[0;34m',
  cyan = '\27[0;36m',
  bold = '\27[1m',
  reset = '\27[0m',
}

function M.strip_ansi(str)
  return str:gsub('\27%[[0-9;]*m', '')
end

function M.print_colored(color, message)
  print(M.colors[color] .. message .. M.colors.reset)
end

function M.print_status(status, message)
  local status_config = {
    info = { color = 'blue', prefix = '[INFO]' },
    success = { color = 'green', prefix = '[PASS]' },
    warning = { color = 'yellow', prefix = '[WARN]' },
    error = { color = 'red', prefix = '[FAIL]' },
  }

  local config = status_config[status]
  if not config then
    print(message)
    return
  end

  local color = M.colors[config.color]
  print(color .. config.prefix .. M.colors.reset .. ' ' .. message)
end

function M.print_separator(char, length)
  char = char or '═'
  length = length or 51
  print(M.colors.bold .. string.rep(char, length) .. M.colors.reset)
end

function M.print_centered(text, width)
  width = width or 51
  local padding = math.floor((width - #text) / 2)
  print(M.colors.bold .. string.rep(' ', padding) .. text .. M.colors.reset)
end

return M
