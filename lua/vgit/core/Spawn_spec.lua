local Spawn = require('vgit.core.Spawn')

local eq = assert.are.same

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

      eq(output, {
        'line1',
        'line2',
        'line3',
        'line4',
        'line5',
        'line6',
      })
    end)
  end)

  describe('line splitting across chunks', function()
    it('joins a line spread over several chunks and flushes the unterminated tail', function()
      local spawn = Spawn({ command = 'true', args = {} })
      local output = {}
      local push = function(line)
        output[#output + 1] = line
      end

      spawn:process_chunk('he', spawn.stdout_buffer, push)
      spawn:process_chunk('ll', spawn.stdout_buffer, push)
      spawn:process_chunk('o\n\nwor', spawn.stdout_buffer, push)
      spawn:process_chunk('ld', spawn.stdout_buffer, push)
      eq({ 'hello', '' }, output)

      spawn:flush(spawn.stdout_buffer, push)
      eq({ 'hello', '', 'world' }, output)
    end)
  end)

  describe('start', function()
    it('spawns process and pipes stdout', function()
      local stdout = {}
      local exited = false

      Spawn({
        command = 'ls',
        args = { '-l' },
        on_stderr = function() end,
        on_stdout = function(line)
          if line ~= '' then table.insert(stdout, line) end
        end,
        on_exit = function()
          exited = true
        end,
      }):start()

      vim.wait(5000, function()
        return exited
      end, 50)
      assert.is_true(exited, 'on_exit should have been called')
      assert.is_true(#stdout > 0, 'should have received stdout output')
    end)

    it('writes stdin to the process', function()
      local stdout = {}
      local exited = false

      Spawn({
        command = 'cat',
        args = {},
        stdin = 'first\nsecond\n',
        on_stderr = function() end,
        on_stdout = function(line)
          if line ~= '' then table.insert(stdout, line) end
        end,
        on_exit = function()
          exited = true
        end,
      }):start()

      vim.wait(5000, function()
        return exited
      end, 50)
      assert.are.same({ 'first', 'second' }, stdout)
    end)

    it('pipes stderr correctly', function()
      local stderr = {}
      local exited = false

      Spawn({
        command = 'ls',
        args = { '-invalid-flag' },
        on_stderr = function(line)
          if line ~= '' then table.insert(stderr, line) end
        end,
        on_stdout = function() end,
        on_exit = function()
          exited = true
        end,
      }):start()

      vim.wait(5000, function()
        return exited
      end, 50)
      assert.is_true(exited, 'on_exit should have been called')
      assert.is_true(#stderr > 0, 'should have received stderr output')
    end)
  end)
end)
