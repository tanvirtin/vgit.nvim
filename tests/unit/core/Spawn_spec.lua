local Spawn = require('vgit.core.Spawn')

describe('Spawn:', function()
  describe('constructor', function()
    it('should construct Spawn with specifications', function()
      Spawn({
        command = 'ls',
        args = { '-l' },
        on_stderr = function() end,
        on_stdout = function() end,
        on_exit = function() end,
      })
    end)
  end)

  describe('line processing', function()
    it('handles split chunks and empty lines', function()
      local spawn = Spawn({
        command = 'echo',
        args = { 'test' },
        on_stdout = function() end,
        on_stderr = function() end,
        on_exit = function() end,
      })

      local output = {}

      spawn:process_chunk('line1\nline2\nline3', spawn.stdout_buffer, function(line)
        table.insert(output, line)
      end)
      spawn:process_chunk('\nline4', spawn.stdout_buffer, function(line)
        table.insert(output, line)
      end)
      spawn:process_chunk('\nline5\nline6\n', spawn.stdout_buffer, function(line)
        table.insert(output, line)
      end)

      assert.are.same(output, {
        'line1',
        'line2',
        'line3',
        'line4',
        'line5',
        'line6',
      })
    end)
  end)

  describe('start', function()
    it('spawns process and pipes stdout', function()
      local stdout = {}

      Spawn({
        command = 'ls',
        args = { '-l' },
        on_stderr = function() end,
        on_stdout = function(line)
          if line ~= '' then table.insert(stdout, line) end
        end,
        on_exit = function()
          assert.is_true(#stdout > 0)
        end,
      }):start()
    end)

    it('pipes stderr correctly', function()
      local stderr = {}

      Spawn({
        command = 'ls',
        args = { '-invalid-flag' },
        on_stderr = function(line)
          if line ~= '' then table.insert(stderr, line) end
        end,
        on_stdout = function() end,
        on_exit = function()
          assert.is_true(#stderr > 0)
        end,
      }):start()
    end)
  end)
end)
