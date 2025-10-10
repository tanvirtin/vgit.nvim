#!/usr/bin/env lua

package.path = package.path .. ';./ops/?.lua;./ops/lib/?.lua'

local shell = require('shell')
local terminal = require('terminal')
local cli = require('cli')
local test_harness = require('test_harness')

local function print_usage()
  print('Usage: lua ops/test_runner.lua [options]')
  print('')
  print('Options:')
  print('  -f, --filter PATTERN   Only run tests matching pattern')
  print('  -p, --path PATH        Test directory or file to run')
  print('  -v, --verbose          Verbose output')
  print('  -h, --help             Show this help message')
  os.exit(0)
end

local function main()
  local args = cli.parse_args({
    ['-h'] = { name = 'help', type = 'action', flags = { '-h', '--help' }, action = print_usage },
    ['-v'] = { name = 'verbose', type = 'boolean', flags = { '-v', '--verbose' } },
    ['-f'] = { name = 'filter', type = 'string', flags = { '-f', '--filter' } },
    ['-p'] = { name = 'path', type = 'string', flags = { '-p', '--path' } },
  })

  local test_path = args.path or 'tests'
  local verbose = args.verbose or false

  terminal.print_colored('blue', 'Running tests from: ' .. test_path)

  local cmd, err = test_harness.build_command(test_path)
  if not cmd then
    terminal.print_status('error', err)
    os.exit(1)
  end

  if verbose then
    print('Command: ' .. cmd)
  end

  local exit_code = os.execute(cmd)
  os.exit(shell.normalize_exit_code(exit_code))
end

local ok, err = pcall(main)
if not ok then
  terminal.print_status('error', err)
  os.exit(1)
end
