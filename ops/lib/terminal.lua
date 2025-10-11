local M = {}

M.colors = {
  red = '\27[0;31m',
  green = '\27[0;32m',
  yellow = '\27[1;33m',
  blue = '\27[0;34m',
  cyan = '\27[0;36m',
  magenta = '\27[0;35m',
  bold = '\27[1m',
  dim = '\27[2m',
  reset = '\27[0m',
}

-- ANSI control codes
M.control = {
  clear_line = '\27[2K',
  cursor_up = '\27[1A',
  cursor_to_start = '\r',
  hide_cursor = '\27[?25l',
  show_cursor = '\27[?25h',
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

-- Spinner animation
M.spinner = {
  frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
  current = 1,
}

function M.spinner:next()
  local frame = self.frames[self.current]
  self.current = (self.current % #self.frames) + 1
  return frame
end

function M.spinner:reset()
  self.current = 1
end

-- Progress bar
function M.progress_bar(current, total, width)
  width = width or 40
  local percentage = (current / total) * 100
  local filled = math.floor((current / total) * width)
  local empty = width - filled

  local bar = M.colors.cyan
      .. '['
      .. M.colors.green
      .. string.rep('█', filled)
      .. M.colors.dim
      .. string.rep('░', empty)
      .. M.colors.cyan
      .. ']'
      .. M.colors.reset

  local text = string.format(' %d/%d (%.1f%%)', current, total, percentage)

  return bar .. M.colors.bold .. text .. M.colors.reset
end

-- Live updating line (overwrites current line)
function M.update_line(text)
  io.write(M.control.cursor_to_start .. M.control.clear_line .. text)
  io.flush()
end

-- Create a progress indicator
function M.create_progress()
  local progress = {
    start_time = os.time(),
    count = 0,
    total = 0,
    passed = 0,
    failed = 0,
    last_file = '',
  }

  function progress:update(opts)
    if opts.count then self.count = opts.count end
    if opts.total then self.total = opts.total end
    if opts.passed then self.passed = opts.passed end
    if opts.failed then self.failed = opts.failed end
    if opts.file then self.last_file = opts.file end
  end

  function progress:render()
    local _elapsed = os.difftime(os.time(), self.start_time)
    local spinner = M.spinner:next()

    local status_text = string.format(
      '%s %s Running tests... %s✓ %d %s✗ %d%s',
      M.colors.cyan,
      spinner,
      M.colors.green,
      self.passed,
      M.colors.red,
      self.failed,
      M.colors.reset
    )

    if self.total > 0 then status_text = status_text .. ' ' .. M.progress_bar(self.count, self.total, 30) end

    if self.last_file ~= '' then
      local file = self.last_file:match('([^/]+)$') or self.last_file
      status_text = status_text .. '\n' .. M.colors.dim .. '  └─ ' .. file .. M.colors.reset
    end

    M.update_line(status_text)
  end

  function progress:finish()
    io.write('\n')
  end

  return progress
end

return M
