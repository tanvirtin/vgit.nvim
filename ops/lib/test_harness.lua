local shell = require('ops.lib.shell')
local terminal = require('ops.lib.terminal')

local M = {}

function M.build_command(path)
  local cmd_type

  if shell.dir_exists(path) then
    cmd_type = 'PlenaryBustedDirectory'
  elseif shell.file_exists(path) then
    cmd_type = 'PlenaryBustedFile'
  else
    return nil, 'Path is not a valid file or directory: ' .. path
  end

  return string.format('nvim --headless -c "%s %s" 2>&1', cmd_type, path)
end

function M.parse_summary(output)
  local success_count = 0
  local failed_count = 0
  local errors_count = 0

  for line in output:gmatch('[^\n]+') do
    local clean = terminal.strip_ansi(line)

    if clean:match('^Success:') then
      local num = tonumber(clean:match('Success:%s*(%d+)'))
      if num then success_count = success_count + num end
    elseif clean:match('^Failed :') then
      local num = tonumber(clean:match('Failed :%s*(%d+)'))
      if num then failed_count = failed_count + num end
    elseif clean:match('^Errors :') then
      local num = tonumber(clean:match('Errors :%s*(%d+)'))
      if num then errors_count = errors_count + num end
    end
  end

  return {
    success = success_count,
    failed = failed_count,
    errors = errors_count,
    total = success_count + failed_count + errors_count,
  }
end

function M.extract_failures(output)
  local failed = {}

  for line in output:gmatch('[^\n]+') do
    local clean = terminal.strip_ansi(line)
    if clean:match('^Fail\t%|%|') then
      local test_name = clean:match('^Fail\t%|%|%s*(.+)')
      if test_name then table.insert(failed, test_name) end
    end
  end

  return failed
end

function M.print_report(summary, failed_tests, elapsed_time)
  local c = terminal.colors

  print('')
  terminal.print_separator('═', 51)
  terminal.print_centered('TEST SUMMARY', 51)
  terminal.print_separator('═', 51)
  print('')

  local label_col_width = 16
  local max_digits = math.max(3, #tostring(summary.total))

  local function print_stat(opts)
    local label_with_colon = opts.label .. ':'
    local padding_needed = label_col_width - #label_with_colon
    local value_str
    if opts.is_string then
      value_str = opts.value
    else
      value_str = string.format('%' .. max_digits .. 'd', opts.value)
    end
    print(
      string.format('  %s%s%s%s%s', opts.color, label_with_colon, c.reset, string.rep(' ', padding_needed), value_str)
    )
  end

  print_stat({ label = '✓ Passed', color = c.green, value = summary.success })
  print_stat({ label = '✗ Failed', color = c.red, value = summary.failed })
  print_stat({ label = '⚠ Errors', color = c.yellow, value = summary.errors })

  if elapsed_time then
    local time_str
    if elapsed_time < 1 then
      time_str = string.format('%.0fms', elapsed_time * 1000)
    else
      time_str = string.format('%.3fs', elapsed_time)
    end
    print_stat({ label = '⏱ Time', color = c.cyan, value = time_str, is_string = true })
  end

  print('')

  local has_failures = summary.failed > 0 or summary.errors > 0

  if has_failures then
    local pass_rate = (summary.success / summary.total) * 100
    local rate_str = string.format('%' .. (max_digits + 1) .. '.1f%%', pass_rate)
    print_stat({ label = 'Pass Rate', color = c.yellow, value = rate_str, is_string = true })
    print('')
    terminal.print_separator('═', 51)
    print('')
    print(c.red .. '✗ Some tests failed!' .. c.reset)
    print('')

    if #failed_tests > 0 then
      print(c.bold .. c.yellow .. 'Failed Tests:' .. c.reset)
      print('')
      for _, test in ipairs(failed_tests) do
        print(string.format('  %s✗%s %s', c.red, c.reset, test))
      end
      print('')
    end

    return false
  else
    local rate_str = string.format('%' .. (max_digits + 1) .. 's', '100.0%')
    print_stat({ label = 'Pass Rate', color = c.green, value = rate_str, is_string = true })
    print('')
    terminal.print_separator('═', 51)
    print('')
    print(c.green .. '✓ All tests passed!' .. c.reset)
    print('')
    return true
  end
end

-- Get high-resolution time using Python (available on macOS and most systems)
local function get_time_seconds()
  local handle = io.popen('python3 -c "import time; print(time.time())" 2>/dev/null')
  if not handle then return nil end
  local result = handle:read('*a')
  handle:close()
  return tonumber(result)
end

function M.run(path, opts)
  opts = opts or {}
  local cmd, err = M.build_command(path)
  if not cmd then return nil, err end

  -- Get wall-clock start time for accurate total (only called once)
  local wall_start
  local get_total_elapsed

  local socket_ok, socket = pcall(require, 'socket')
  if socket_ok and socket.gettime then
    -- LuaSocket available - fast high-resolution timer
    wall_start = socket.gettime()
    get_total_elapsed = function()
      return socket.gettime() - wall_start
    end
  else
    -- Fallback: Python for accurate wall-clock (only called at start/end)
    wall_start = get_time_seconds()
    if wall_start then
      get_total_elapsed = function()
        local end_time = get_time_seconds()
        return end_time and (end_time - wall_start) or 0
      end
    else
      -- Last resort: os.time (1-second resolution)
      wall_start = os.time()
      get_total_elapsed = function()
        return os.difftime(os.time(), wall_start)
      end
    end
  end

  local output

  if opts.stream then
    -- Streaming with periodic time updates
    local line_count = 0
    local display_interval = 50 -- Show elapsed time every N lines
    local should_show_time = false

    output = shell.stream(cmd, function(line)
      print(line)
      line_count = line_count + 1

      -- Check if we should show time at next separator
      if line_count % display_interval == 0 then should_show_time = true end

      -- Show elapsed time after separator lines (clean break point)
      if should_show_time and line:match('^========') then
        local elapsed = get_total_elapsed()
        local time_str
        if elapsed < 1 then
          time_str = string.format('%dms', math.floor(elapsed * 1000))
        else
          time_str = string.format('%.2fs', elapsed)
        end
        print(
          string.format(
            '\n%s%s⏱  %s elapsed so far%s\n',
            terminal.colors.cyan,
            terminal.colors.bold,
            time_str,
            terminal.colors.reset
          )
        )
        should_show_time = false
      end

      io.stdout:flush()
    end)
  else
    output = shell.capture(cmd)
  end

  -- Use wall-clock timer for accurate total time (only called once at end)
  local total_time = get_total_elapsed()

  if not output then return nil, 'Could not run tests' end

  return {
    output = output,
    summary = M.parse_summary(output),
    failed_tests = M.extract_failures(output),
    elapsed_time = total_time,
  }
end

return M
