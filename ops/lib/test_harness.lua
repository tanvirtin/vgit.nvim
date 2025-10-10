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
      if test_name then
        table.insert(failed, test_name)
      end
    end
  end

  return failed
end

function M.print_report(summary, failed_tests)
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
    print(string.format('  %s%s%s%s%s',
      opts.color, label_with_colon, c.reset, string.rep(' ', padding_needed), value_str))
  end

  print_stat({ label = '✓ Passed', color = c.green, value = summary.success })
  print_stat({ label = '✗ Failed', color = c.red, value = summary.failed })
  print_stat({ label = '⚠ Errors', color = c.yellow, value = summary.errors })
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

function M.run(path)
  local cmd, err = M.build_command(path)
  if not cmd then
    return nil, err
  end

  local output, success = shell.capture(cmd)
  if not output then
    return nil, 'Could not run tests'
  end

  return {
    output = output,
    summary = M.parse_summary(output),
    failed_tests = M.extract_failures(output),
  }
end

return M
