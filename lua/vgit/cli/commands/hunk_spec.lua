local eq = assert.are.same
local hunk_command = require('vgit.cli.commands.hunk')

describe('hunk_command:', function()
  describe('find_target_hunk_index', function()
    it('should return nil if diff is nil', function()
      local result = hunk_command.find_target_hunk_index(nil, 5)
      eq(nil, result)
    end)

    it('should return nil if diff.marks is nil', function()
      local result = hunk_command.find_target_hunk_index({}, 5)
      eq(nil, result)
    end)

    it('should return nil if diff.marks is empty', function()
      local result = hunk_command.find_target_hunk_index({ marks = {} }, 5)
      eq(nil, result)
    end)

    it('should return nil if lnum is outside all marks', function()
      local diff = {
        marks = {
          { top_relative = 1, bot_relative = 5 },
          { top_relative = 10, bot_relative = 15 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 7)
      eq(nil, result)
    end)

    it('should return index when lnum is within first mark', function()
      local diff = {
        marks = {
          { top_relative = 1, bot_relative = 5 },
          { top_relative = 10, bot_relative = 15 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 3)
      eq(1, result)
    end)

    it('should return index when lnum is within second mark', function()
      local diff = {
        marks = {
          { top_relative = 1, bot_relative = 5 },
          { top_relative = 10, bot_relative = 15 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 12)
      eq(2, result)
    end)

    it('should return index when lnum is at mark boundary', function()
      local diff = {
        marks = {
          { top_relative = 1, bot_relative = 5 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 1)
      eq(1, result)
    end)

    it('should return index when lnum is at mark upper boundary', function()
      local diff = {
        marks = {
          { top_relative = 1, bot_relative = 5 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 5)
      eq(1, result)
    end)

    it('should return index when marks lack top_relative', function()
      local diff = {
        marks = {
          { bot_relative = 5 },
          { top_relative = 10, bot_relative = 15 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 12)
      eq(2, result)
    end)

    it('should return index when marks lack bot_relative', function()
      local diff = {
        marks = {
          { top_relative = 1 },
          { top_relative = 10, bot_relative = 15 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 12)
      eq(2, result)
    end)

    it('should return nil if lnum is 0', function()
      local diff = {
        marks = {
          { top_relative = 1, bot_relative = 5 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 0)
      eq(nil, result)
    end)

    it('should return first mark when lnum is before first mark', function()
      local diff = {
        marks = {
          { top_relative = 5, bot_relative = 10 },
          { top_relative = 15, bot_relative = 20 },
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 3)
      eq(nil, result)
    end)

    it('should return nil if all marks lack both boundaries', function()
      local diff = {
        marks = {
          {},
          {},
        },
      }
      local result = hunk_command.find_target_hunk_index(diff, 5)
      eq(nil, result)
    end)
  end)
end)
