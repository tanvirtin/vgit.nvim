#!/usr/bin/env lua

package.path = package.path .. ';./ops/?.lua;./ops/lib/?.lua'

local terminal = require('terminal')
local test_harness = require('test_harness')

local function main()
  local test_path = arg[1] or 'tests/unit'
  local use_progress = os.getenv('NO_COLOR') == nil

  terminal.print_colored('blue', 'Running tests from: ' .. test_path)
  print('')

  local results, err = test_harness.run(test_path, {
    stream = true,
    progress = use_progress,
  })

  if not results then
    terminal.print_status('error', err)
    os.exit(1)
  end

  -- Output already printed via streaming, just show summary
  local all_passed = test_harness.print_report(results.summary, results.failed_tests)

  os.exit(all_passed and 0 or 1)
end

main()
