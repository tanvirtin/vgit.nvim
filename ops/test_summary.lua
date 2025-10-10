#!/usr/bin/env lua

package.path = package.path .. ';./ops/?.lua;./ops/lib/?.lua'

local terminal = require('terminal')
local test_harness = require('test_harness')

local function main()
  local test_path = arg[1] or 'tests/unit'

  terminal.print_colored('blue', 'Running tests from: ' .. test_path)
  print('')

  local results, err = test_harness.run(test_path)
  if not results then
    terminal.print_status('error', err)
    os.exit(1)
  end

  print(results.output)

  local all_passed = test_harness.print_report(results.summary, results.failed_tests)

  os.exit(all_passed and 0 or 1)
end

main()
