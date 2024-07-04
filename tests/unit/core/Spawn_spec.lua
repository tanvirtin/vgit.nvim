local utils = require('vgit.core.utils')
local Spawn = require('vgit.core.Spawn')

describe('Spawn:', function()
  describe('constructor', function()
    it('should be able to construct Spawn with specifications', function()
      Spawn({
        command = 'ls',
        args = { '-l' },
        on_stderr = function() end,
        on_stdout = function() end,
        on_exit = function() end,
      })
    end)
  end)

  describe('parse_result', function()
    it('parses the output correctly', function()
      local spawn = Spawn({
        command = 'ls',
        args = { '-l' },
        on_stderr = function()
        end,
        on_stdout = function()
        end,
        on_exit = function()
        end,
      })
      local output = {}
      spawn:parse_result({'line1\nline2\nline3', '\nline4', '\nline5\nline6'}, function(line)
        table.insert(output, line)
      end)
      assert.are.same(table.concat(output), 'line1line2line3line4line5line6')
    end)
  end)

  describe('start', function()
    it('should be able to spawn a process and pipe stdout', function()
      local stdout = {}

      Spawn({
        command = 'ls',
        args = { '-l' },
        on_stderr = function() end,
        on_stdout = function(line)
          table.insert(stdout, line)
        end,
        on_exit = function()
          assert.is_true(not utils.list.is_empty(stdout))
        end,
      }):start()
    end)

    it('should pipe stderr correctly', function()
      local stderr = {}
      local stdout = {}

      Spawn({
        command = 'ls',
        args = { '-lasdasd' },
        on_stderr = function(line)
          table.insert(stdout, line)
        end,
        on_stdout = function(line)
          table.insert(stdout, line)
        end,
        on_exit = function()
          assert.is_true(utils.list.is_empty(stderr))
          assert.is_true(not utils.list.is_empty(stdout))
        end,
      }):start()
    end)
  end)
end)
