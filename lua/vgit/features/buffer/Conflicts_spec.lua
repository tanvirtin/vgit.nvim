local eq = assert.are.same

-- Stubs must be set up before requiring Conflicts, because it captures
-- module-level references at require time.

local navigation_up_calls = {}
local navigation_down_calls = {}

local navigation_stub = {
  up = function(window, marks)
    navigation_up_calls[#navigation_up_calls + 1] = { window = window, marks = marks }
  end,
  down = function(window, marks)
    navigation_down_calls[#navigation_down_calls + 1] = { window = window, marks = marks }
  end,
}

local git_buffer_store_stub = {
  current = function()
    return nil
  end,
}

local window_get_cursor_return = { 1, 0 }
local window_instance = {
  get_cursor = function()
    return window_get_cursor_return
  end,
}
local Window_stub = setmetatable({}, {
  __index = require('vgit.core.Object'),
  __call = function(_, ...)
    return window_instance
  end,
})

package.loaded['vgit.core.navigation'] = navigation_stub
package.loaded['vgit.git.git_buffer_store'] = git_buffer_store_stub
package.loaded['vgit.core.Window'] = Window_stub

local Conflicts = require('vgit.features.buffer.Conflicts')

describe('Conflicts:', function()
  before_each(function()
    -- Reset stubs before each test
    navigation_up_calls = {}
    navigation_down_calls = {}
    git_buffer_store_stub.current = function()
      return nil
    end
    window_get_cursor_return = { 1, 0 }
  end)

  describe('constructor', function()
    it('should create instance with name "Buffer Conflicts"', function()
      local conflicts = Conflicts()
      eq('Buffer Conflicts', conflicts._name)
    end)
  end)

  describe('hunk_up', function()
    it('should return early when there is no current buffer', function()
      git_buffer_store_stub.current = function()
        return nil
      end

      local conflicts = Conflicts()
      conflicts:hunk_up()

      eq(0, #navigation_up_calls)
    end)

    it('should return early when conflicts is nil', function()
      local mock_buffer = {
        get_conflicts = function()
          return nil
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      conflicts:hunk_up()

      eq(0, #navigation_up_calls)
    end)

    it('should return early when conflicts is empty', function()
      local mock_buffer = {
        get_conflicts = function()
          return {}
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      conflicts:hunk_up()

      eq(0, #navigation_up_calls)
    end)

    it('should call navigation.up with window and conflict marks', function()
      local mock_marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
      local mock_buffer = {
        get_conflicts = function()
          return { { current = {}, incoming = {} } }
        end,
        get_conflict_marks = function()
          return mock_marks
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      conflicts:hunk_up()

      eq(1, #navigation_up_calls)
      eq(window_instance, navigation_up_calls[1].window)
      eq(mock_marks, navigation_up_calls[1].marks)
    end)
  end)

  describe('hunk_down', function()
    it('should return early when there is no current buffer', function()
      git_buffer_store_stub.current = function()
        return nil
      end

      local conflicts = Conflicts()
      conflicts:hunk_down()

      eq(0, #navigation_down_calls)
    end)

    it('should return early when conflicts is nil', function()
      local mock_buffer = {
        get_conflicts = function()
          return nil
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      conflicts:hunk_down()

      eq(0, #navigation_down_calls)
    end)

    it('should return early when conflicts is empty', function()
      local mock_buffer = {
        get_conflicts = function()
          return {}
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      conflicts:hunk_down()

      eq(0, #navigation_down_calls)
    end)

    it('should call navigation.down with window and conflict marks', function()
      local mock_marks = { { top = 1, bot = 5 }, { top = 10, bot = 15 } }
      local mock_buffer = {
        get_conflicts = function()
          return { { current = {}, incoming = {} } }
        end,
        get_conflict_marks = function()
          return mock_marks
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      conflicts:hunk_down()

      eq(1, #navigation_down_calls)
      eq(window_instance, navigation_down_calls[1].window)
      eq(mock_marks, navigation_down_calls[1].marks)
    end)
  end)

  describe('accept_both', function()
    it('should return early when there is no current buffer', function()
      git_buffer_store_stub.current = function()
        return nil
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_both()

      assert.is_nil(result)
    end)

    it('should return early when conflicts is nil', function()
      local mock_buffer = {
        get_conflicts = function()
          return nil
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_both()

      assert.is_nil(result)
    end)

    it('should return early when conflicts is empty', function()
      local mock_buffer = {
        get_conflicts = function()
          return {}
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_both()

      assert.is_nil(result)
    end)

    it('should return early when no conflict is found at cursor position', function()
      local set_lines_called = false
      local mock_buffer = {
        get_conflicts = function()
          return { { current = { top = 1, bot = 3 }, incoming = { top = 5, bot = 7 } } }
        end,
        get_conflict = function(_, lnum)
          return nil
        end,
        set_lines = function()
          set_lines_called = true
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 20, 0 }

      local conflicts = Conflicts()
      conflicts:accept_both()

      eq(false, set_lines_called)
    end)

    it('should merge both current and incoming lines and remove markers', function()
      -- Simulate a conflict block in the middle of a file:
      -- Line 1: "before conflict"
      -- Line 2: "<<<<<<< HEAD"       -- current.top = 2
      -- Line 3: "current line 1"
      -- Line 4: "current line 2"     -- current.bot = 4
      -- Line 5: "======="            -- separator
      -- Line 6: "incoming line 1"    -- incoming.top = 6
      -- Line 7: "incoming line 2"
      -- Line 8: ">>>>>>> branch"     -- incoming.bot = 8
      -- Line 9: "after conflict"
      local lines = {
        'before conflict',
        '<<<<<<< HEAD',
        'current line 1',
        'current line 2',
        '=======',
        'incoming line 1',
        'incoming line 2',
        '>>>>>>> branch',
        'after conflict',
      }

      local conflict = {
        current = { top = 2, bot = 4 },
        incoming = { top = 6, bot = 8 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 3, 0 }

      local conflicts = Conflicts()
      conflicts:accept_both()

      -- The entire conflict block (lines 2-8) should be replaced
      -- with current content (lines 3-4) + incoming content (lines 6-7).
      eq({
        'before conflict',
        'current line 1',
        'current line 2',
        'incoming line 1',
        'incoming line 2',
        'after conflict',
      }, captured_lines)
    end)

    it('should handle a conflict at the start of the file', function()
      -- Line 1: "<<<<<<< HEAD"       -- current.top = 1
      -- Line 2: "my change"          -- current.bot = 2
      -- Line 3: "======="
      -- Line 4: "their change"       -- incoming.top = 4
      -- Line 5: ">>>>>>> branch"     -- incoming.bot = 5
      -- Line 6: "rest of file"
      local lines = {
        '<<<<<<< HEAD',
        'my change',
        '=======',
        'their change',
        '>>>>>>> branch',
        'rest of file',
      }

      local conflict = {
        current = { top = 1, bot = 2 },
        incoming = { top = 4, bot = 5 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 2, 0 }

      local conflicts = Conflicts()
      conflicts:accept_both()

      eq({
        'my change',
        'their change',
        'rest of file',
      }, captured_lines)
    end)

    it('should handle a conflict with multiple current and incoming lines', function()
      local lines = {
        'header',
        '<<<<<<< HEAD',
        'c1',
        'c2',
        'c3',
        '=======',
        'i1',
        'i2',
        'i3',
        'i4',
        '>>>>>>> feature',
        'footer',
      }

      local conflict = {
        current = { top = 2, bot = 5 },
        incoming = { top = 7, bot = 11 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 4, 0 }

      local conflicts = Conflicts()
      conflicts:accept_both()

      eq({
        'header',
        'c1',
        'c2',
        'c3',
        'i1',
        'i2',
        'i3',
        'i4',
        'footer',
      }, captured_lines)
    end)

    it('should handle single-line current and incoming content', function()
      local lines = {
        '<<<<<<< HEAD',
        'only current',
        '=======',
        'only incoming',
        '>>>>>>> branch',
      }

      local conflict = {
        current = { top = 1, bot = 2 },
        incoming = { top = 4, bot = 5 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 1, 0 }

      local conflicts = Conflicts()
      conflicts:accept_both()

      eq({
        'only current',
        'only incoming',
      }, captured_lines)
    end)
  end)

  describe('accept_current', function()
    it('should return early when there is no current buffer', function()
      git_buffer_store_stub.current = function()
        return nil
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_current()

      assert.is_nil(result)
    end)

    it('should return early when conflicts is nil', function()
      local mock_buffer = {
        get_conflicts = function()
          return nil
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_current()

      assert.is_nil(result)
    end)

    it('should return early when conflicts is empty', function()
      local mock_buffer = {
        get_conflicts = function()
          return {}
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_current()

      assert.is_nil(result)
    end)

    it('should return early when no conflict is found at cursor position', function()
      local set_lines_called = false
      local mock_buffer = {
        get_conflicts = function()
          return { { current = { top = 1, bot = 3 }, incoming = { top = 5, bot = 7 } } }
        end,
        get_conflict = function(_, lnum)
          return nil
        end,
        set_lines = function()
          set_lines_called = true
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 50, 0 }

      local conflicts = Conflicts()
      conflicts:accept_current()

      eq(false, set_lines_called)
    end)

    it('should keep only current lines and remove incoming and all markers', function()
      local lines = {
        'before conflict',
        '<<<<<<< HEAD',
        'current line 1',
        'current line 2',
        '=======',
        'incoming line 1',
        'incoming line 2',
        '>>>>>>> branch',
        'after conflict',
      }

      local conflict = {
        current = { top = 2, bot = 4 },
        incoming = { top = 6, bot = 8 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 3, 0 }

      local conflicts = Conflicts()
      conflicts:accept_current()

      eq({
        'before conflict',
        'current line 1',
        'current line 2',
        'after conflict',
      }, captured_lines)
    end)

    it('should handle a conflict at the start of the file', function()
      local lines = {
        '<<<<<<< HEAD',
        'my change',
        '=======',
        'their change',
        '>>>>>>> branch',
        'rest of file',
      }

      local conflict = {
        current = { top = 1, bot = 2 },
        incoming = { top = 4, bot = 5 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 2, 0 }

      local conflicts = Conflicts()
      conflicts:accept_current()

      eq({
        'my change',
        'rest of file',
      }, captured_lines)
    end)

    it('should handle multiple lines of current content', function()
      local lines = {
        'header',
        '<<<<<<< HEAD',
        'c1',
        'c2',
        'c3',
        '=======',
        'i1',
        'i2',
        '>>>>>>> feature',
        'footer',
      }

      local conflict = {
        current = { top = 2, bot = 5 },
        incoming = { top = 7, bot = 9 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 3, 0 }

      local conflicts = Conflicts()
      conflicts:accept_current()

      eq({
        'header',
        'c1',
        'c2',
        'c3',
        'footer',
      }, captured_lines)
    end)

    it('should handle single-line current content', function()
      local lines = {
        '<<<<<<< HEAD',
        'only current',
        '=======',
        'only incoming',
        '>>>>>>> branch',
      }

      local conflict = {
        current = { top = 1, bot = 2 },
        incoming = { top = 4, bot = 5 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 2, 0 }

      local conflicts = Conflicts()
      conflicts:accept_current()

      eq({
        'only current',
      }, captured_lines)
    end)
  end)

  describe('accept_incoming', function()
    it('should return early when there is no current buffer', function()
      git_buffer_store_stub.current = function()
        return nil
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_incoming()

      assert.is_nil(result)
    end)

    it('should return early when conflicts is nil', function()
      local mock_buffer = {
        get_conflicts = function()
          return nil
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_incoming()

      assert.is_nil(result)
    end)

    it('should return early when conflicts is empty', function()
      local mock_buffer = {
        get_conflicts = function()
          return {}
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end

      local conflicts = Conflicts()
      local result = conflicts:accept_incoming()

      assert.is_nil(result)
    end)

    it('should return early when no conflict is found at cursor position', function()
      local set_lines_called = false
      local mock_buffer = {
        get_conflicts = function()
          return { { current = { top = 1, bot = 3 }, incoming = { top = 5, bot = 7 } } }
        end,
        get_conflict = function(_, lnum)
          return nil
        end,
        set_lines = function()
          set_lines_called = true
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 50, 0 }

      local conflicts = Conflicts()
      conflicts:accept_incoming()

      eq(false, set_lines_called)
    end)

    it('should keep only incoming lines and remove current and all markers', function()
      local lines = {
        'before conflict',
        '<<<<<<< HEAD',
        'current line 1',
        'current line 2',
        '=======',
        'incoming line 1',
        'incoming line 2',
        '>>>>>>> branch',
        'after conflict',
      }

      local conflict = {
        current = { top = 2, bot = 4 },
        incoming = { top = 6, bot = 8 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 6, 0 }

      local conflicts = Conflicts()
      conflicts:accept_incoming()

      eq({
        'before conflict',
        'incoming line 1',
        'incoming line 2',
        'after conflict',
      }, captured_lines)
    end)

    it('should handle a conflict at the start of the file', function()
      local lines = {
        '<<<<<<< HEAD',
        'my change',
        '=======',
        'their change',
        '>>>>>>> branch',
        'rest of file',
      }

      local conflict = {
        current = { top = 1, bot = 2 },
        incoming = { top = 4, bot = 5 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 4, 0 }

      local conflicts = Conflicts()
      conflicts:accept_incoming()

      eq({
        'their change',
        'rest of file',
      }, captured_lines)
    end)

    it('should handle multiple lines of incoming content', function()
      local lines = {
        'header',
        '<<<<<<< HEAD',
        'c1',
        'c2',
        '=======',
        'i1',
        'i2',
        'i3',
        '>>>>>>> feature',
        'footer',
      }

      local conflict = {
        current = { top = 2, bot = 4 },
        incoming = { top = 6, bot = 9 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 7, 0 }

      local conflicts = Conflicts()
      conflicts:accept_incoming()

      eq({
        'header',
        'i1',
        'i2',
        'i3',
        'footer',
      }, captured_lines)
    end)

    it('should handle single-line incoming content', function()
      local lines = {
        '<<<<<<< HEAD',
        'only current',
        '=======',
        'only incoming',
        '>>>>>>> branch',
      }

      local conflict = {
        current = { top = 1, bot = 2 },
        incoming = { top = 4, bot = 5 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 4, 0 }

      local conflicts = Conflicts()
      conflicts:accept_incoming()

      eq({
        'only incoming',
      }, captured_lines)
    end)

    it('should handle a conflict at the end of the file', function()
      local lines = {
        'beginning of file',
        'some content',
        '<<<<<<< HEAD',
        'current end',
        '=======',
        'incoming end',
        '>>>>>>> branch',
      }

      local conflict = {
        current = { top = 3, bot = 4 },
        incoming = { top = 6, bot = 7 },
      }

      local captured_lines = nil
      local mock_buffer = {
        get_conflicts = function()
          return { conflict }
        end,
        get_conflict = function(_, lnum)
          return conflict
        end,
        get_lines = function()
          return lines
        end,
        set_lines = function(_, new_lines)
          captured_lines = new_lines
        end,
      }
      git_buffer_store_stub.current = function()
        return mock_buffer
      end
      window_get_cursor_return = { 6, 0 }

      local conflicts = Conflicts()
      conflicts:accept_incoming()

      eq({
        'beginning of file',
        'some content',
        'incoming end',
      }, captured_lines)
    end)
  end)
end)
