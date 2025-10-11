local async = require('plenary.async.tests')
local gitcli = require('vgit.git.gitcli')

local eq = assert.are.same

async.describe('gitcli:', function()
  local original_Spawn
  local mock_spawn_instance
  local spawn_spec

  async.before_each(function()
    -- Save original Spawn
    original_Spawn = package.loaded['vgit.core.Spawn']

    -- Create mock spawn instance
    mock_spawn_instance = {
      start = function()
        return mock_spawn_instance
      end,
    }

    -- Mock Spawn constructor
    package.loaded['vgit.core.Spawn'] = function(spec)
      spawn_spec = spec -- Capture the spawn spec
      return mock_spawn_instance
    end

    -- Reload gitcli to use mocked Spawn
    package.loaded['vgit.git.gitcli'] = nil
    gitcli = require('vgit.git.gitcli')
  end)

  async.after_each(function()
    -- Restore original Spawn
    package.loaded['vgit.core.Spawn'] = original_Spawn
    package.loaded['vgit.git.gitcli'] = nil
    spawn_spec = nil
  end)

  async.describe('run()', function()
    async.it('should execute git command with arguments', function()
      gitcli.run({ 'status', '-s' }, nil, function(stdout, error)
        -- Intentionally not capturing result for this test
      end)

      -- Wait for async to settle
      vim.wait(100)

      -- Verify Spawn was called with correct command
      assert(spawn_spec, 'Spawn should have been called')
      eq(spawn_spec.command, 'git')
      eq(spawn_spec.args, { 'status', '-s' })
    end)

    async.it('should collect stdout lines', function()
      local result, err

      gitcli.run({ 'log', '--oneline' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Simulate stdout output
      assert(spawn_spec.on_stdout, 'on_stdout callback should exist')
      spawn_spec.on_stdout('line 1')
      spawn_spec.on_stdout('line 2')
      spawn_spec.on_stdout('line 3')

      -- Simulate exit
      spawn_spec.on_exit()

      vim.wait(100)

      assert(not err, 'Should not have error')
      assert(result, 'Should have result')
      eq(#result, 3)
      eq(result[1], 'line 1')
      eq(result[2], 'line 2')
      eq(result[3], 'line 3')
    end)

    async.it('should collect stderr and return as error', function()
      local result, err

      gitcli.run({ 'invalid-command' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Simulate stderr output
      assert(spawn_spec.on_stderr, 'on_stderr callback should exist')
      spawn_spec.on_stderr('error: invalid command')
      spawn_spec.on_stderr('usage: git ...')

      -- Simulate exit
      spawn_spec.on_exit()

      vim.wait(100)

      assert(err, 'Should have error')
      assert(not result, 'Should not have result')
      eq(#err, 2)
      eq(err[1], 'error: invalid command')
      eq(err[2], 'usage: git ...')
    end)

    async.it('should handle empty stdout', function()
      local result, err

      gitcli.run({ 'status', '-s' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Simulate exit without output
      spawn_spec.on_exit()

      vim.wait(100)

      assert(not err, 'Should not have error')
      assert(result, 'Should have result')
      eq(#result, 0)
    end)

    async.it('should prefer stderr over stdout when both exist', function()
      local result, err

      gitcli.run({ 'command' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Simulate both stdout and stderr
      spawn_spec.on_stdout('some output')
      spawn_spec.on_stderr('error occurred')

      -- Simulate exit
      spawn_spec.on_exit()

      vim.wait(100)

      -- Should return error, not stdout
      assert(err, 'Should have error')
      assert(not result, 'Should not have result when error exists')
      eq(err[1], 'error occurred')
    end)

    async.it('should handle debug option', function()
      local console_output = {}
      local original_console_info = require('vgit.core.console').info

      -- Mock console.info
      require('vgit.core.console').info = function(msg)
        table.insert(console_output, msg)
      end

      gitcli.run({ 'status', '-s' }, { debug = true }, function() end)

      vim.wait(100)

      -- Restore console.info
      require('vgit.core.console').info = original_console_info

      -- Verify debug output
      assert(#console_output > 0, 'Should have debug output')
      assert(console_output[1]:match('git'), 'Should contain git command')
      assert(console_output[1]:match('status'), 'Should contain args')
    end)

    async.it('should not output debug when debug is false', function()
      local console_output = {}
      local original_console_info = require('vgit.core.console').info

      -- Mock console.info
      require('vgit.core.console').info = function(msg)
        table.insert(console_output, msg)
      end

      gitcli.run({ 'status', '-s' }, { debug = false }, function() end)

      vim.wait(100)

      -- Restore console.info
      require('vgit.core.console').info = original_console_info

      -- Verify no debug output
      eq(#console_output, 0)
    end)

    async.it('should handle nil opts gracefully', function()
      gitcli.run({ 'status' }, nil, function(stdout, error)
        -- Not capturing for this test - just checking spawn_spec
      end)

      vim.wait(100)

      -- Should not error when opts is nil
      assert(spawn_spec, 'Spawn should have been called')
      eq(spawn_spec.command, 'git')
    end)

    async.it('should handle multiple stdout lines in one chunk', function()
      local result, err

      gitcli.run({ 'log' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Simulate multiple lines
      spawn_spec.on_stdout('line 1')
      spawn_spec.on_stdout('line 2')
      spawn_spec.on_stdout('line 3')
      spawn_spec.on_stdout('line 4')
      spawn_spec.on_stdout('line 5')

      spawn_spec.on_exit()

      vim.wait(100)

      assert(not err)
      assert(result)
      eq(#result, 5)
    end)

    async.it('should handle mixed stdout and stderr order', function()
      local result, err

      gitcli.run({ 'command' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Simulate interleaved output
      spawn_spec.on_stdout('stdout 1')
      spawn_spec.on_stderr('stderr 1')
      spawn_spec.on_stdout('stdout 2')
      spawn_spec.on_stderr('stderr 2')

      spawn_spec.on_exit()

      vim.wait(100)

      -- Should have error since stderr has content
      assert(err)
      assert(not result)
      eq(#err, 2)
      eq(err[1], 'stderr 1')
      eq(err[2], 'stderr 2')
    end)

    async.it('should handle Unicode in output', function()
      local result, err

      gitcli.run({ 'log' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      spawn_spec.on_stdout('commit with emoji 🎉')
      spawn_spec.on_stdout('commit with 中文')
      spawn_spec.on_stdout('commit with Ñoño')

      spawn_spec.on_exit()

      vim.wait(100)

      assert(not err)
      eq(#result, 3)
      assert(result[1]:match('🎉'))
      assert(result[2]:match('中文'))
      assert(result[3]:match('Ñoño'))
    end)

    async.it('should handle special characters in output', function()
      local result, err

      gitcli.run({ 'log' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      spawn_spec.on_stdout('line with "quotes"')
      spawn_spec.on_stdout('line with \'single quotes\'')
      spawn_spec.on_stdout('line with symbols &<>')

      spawn_spec.on_exit()

      vim.wait(100)

      assert(not err)
      eq(#result, 3)
      eq(result[1], 'line with "quotes"')
      eq(result[2], 'line with \'single quotes\'')
      eq(result[3], 'line with symbols &<>')
    end)

    async.it('should handle very long output', function()
      local result, err

      gitcli.run({ 'log' }, nil, function(stdout, error)
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Simulate many lines
      for i = 1, 1000 do
        spawn_spec.on_stdout('line ' .. i)
      end

      spawn_spec.on_exit()

      vim.wait(100)

      assert(not err)
      eq(#result, 1000)
      eq(result[1], 'line 1')
      eq(result[1000], 'line 1000')
    end)

    async.it('should invoke callback exactly once with aggregated output', function()
      local call_count = 0
      local result, err

      gitcli.run({ 'status' }, nil, function(stdout, error)
        call_count = call_count + 1
        result = stdout
        err = error
      end)

      vim.wait(100)

      -- Multiple stdout calls should be aggregated
      spawn_spec.on_stdout('line 1')
      spawn_spec.on_stdout('line 2')
      spawn_spec.on_stdout('line 3')

      -- Exit should trigger callback once with all lines
      spawn_spec.on_exit()

      vim.wait(100)

      -- Callback should be called exactly once
      eq(call_count, 1, 'Callback should be invoked exactly once')
      assert(not err, 'Should not have error')
      assert(result, 'Should have result')
      eq(#result, 3, 'Should have all 3 lines')
      eq(result[1], 'line 1')
      eq(result[2], 'line 2')
      eq(result[3], 'line 3')
    end)

    async.it('should handle args with spaces', function()
      gitcli.run({ 'commit', '-m', 'message with spaces' }, nil, function() end)

      vim.wait(100)

      eq(spawn_spec.args[1], 'commit')
      eq(spawn_spec.args[2], '-m')
      eq(spawn_spec.args[3], 'message with spaces')
    end)

    async.it('should handle args with special characters', function()
      gitcli.run({ 'commit', '-m', 'fix: bug with "quotes" & symbols' }, nil, function() end)

      vim.wait(100)

      eq(spawn_spec.args[3], 'fix: bug with "quotes" & symbols')
    end)

    async.it('should handle empty args array', function()
      gitcli.run({}, nil, function() end)

      vim.wait(100)

      assert(spawn_spec)
      eq(spawn_spec.command, 'git')
      eq(#spawn_spec.args, 0)
    end)
  end)

  async.describe('integration patterns', function()
    async.it('should work with common git status command', function()
      gitcli.run({ '-C', '/repo', 'status', '-s' }, nil, function(stdout, error)
        -- Not capturing for this test - just checking spawn args
      end)

      vim.wait(100)

      eq(spawn_spec.args[1], '-C')
      eq(spawn_spec.args[2], '/repo')
      eq(spawn_spec.args[3], 'status')
      eq(spawn_spec.args[4], '-s')
    end)

    async.it('should work with git log format command', function()
      gitcli.run({ 'log', '--pretty=format:%H %s', '-n', '10' }, nil, function() end)

      vim.wait(100)

      eq(spawn_spec.args[1], 'log')
      eq(spawn_spec.args[2], '--pretty=format:%H %s')
      eq(spawn_spec.args[3], '-n')
      eq(spawn_spec.args[4], '10')
    end)

    async.it('should work with git show command', function()
      gitcli.run({ 'show', 'HEAD:file.txt' }, nil, function() end)

      vim.wait(100)

      eq(spawn_spec.args[1], 'show')
      eq(spawn_spec.args[2], 'HEAD:file.txt')
    end)
  end)
end)
