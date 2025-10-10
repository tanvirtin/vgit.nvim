#!/usr/bin/env lua

-- Pre-commit hook for vgit.nvim

package.path = package.path .. ';./ops/?.lua;./ops/lib/?.lua'

local shell = require('shell')
local terminal = require('terminal')

local function run_check(opts)
  terminal.print_status('info', 'Running ' .. opts.name .. '...')

  if not shell.execute(opts.command, opts.output_file) then
    terminal.print_status('error', opts.name .. ' failed')
    print('')

    local tail = shell.tail(opts.output_file, 20)
    if tail then
      print(tail)
    end

    print('')
    if opts.help_text then
      print(opts.help_text)
    end
    return false
  else
    terminal.print_status('success', opts.name .. ' passed')
    return true
  end
end

local function main()
  print('Running pre-commit checks...')
  print('')

  if not shell.file_exists('Makefile') then
    terminal.print_status('error', 'Not in vgit.nvim root directory')
    os.exit(1)
  end

  local check_passed = run_check({
    name = 'Lint and format checks',
    command = 'make check',
    output_file = '/tmp/vgit-check-output.log',
    help_text = 'Run: make format (to auto-fix formatting)\nRun: make check (to see all issues)',
  })

  if not check_passed then
    os.exit(1)
  end

  print('')

  local tests_passed = run_check({
    name = 'Tests',
    command = 'make test',
    output_file = '/tmp/vgit-test-output.log',
    help_text = 'Run: make test',
  })

  if not tests_passed then
    os.exit(1)
  end

  print('')
  terminal.print_status('success', 'All pre-commit checks passed!')
  print('')
end

main()
