local mock = require('luassert.mock')
local a = require('plenary.async.tests')
local Window = require('vgit.core.Window')
local navigation = require('vgit.core.navigation')

local eq = assert.are.same

a.describe('navigation:', function()
  local window = Window(0)
  local marks = {
    {
      top = 30,
      bot = 40,
    },
    {
      top = 50,
      bot = 60,
    },
    {
      top = 65,
      bot = 95,
    },
    {
      top = 95,
      bot = 105,
    },
    {
      top = 300,
      bot = 400,
    },
    {
      top = 410,
      bot = 410,
    },
  }

  before_each(function()
    vim.api.nvim_win_set_cursor = mock(vim.api.nvim_win_set_cursor, true)
  end)
  after_each(function()
    mock.revert(vim.api.nvim_win_set_cursor)
  end)

  a.describe('up', function()
    a.it('should select the last mark when the cursor is above the first mark', function()
      for i = 1, marks[1].top do
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ i, 0 })
        eq(navigation.up(window, marks), #marks)
      end
    end)
    a.it('should select the second last mark if the cursor is inside the last mark', function()
      for i = marks[#marks].top, marks[#marks - 1].bot, -1 do
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ i, 0 })
        eq(navigation.up(window, marks), #marks - 1)
      end
    end)
    a.it('should jump to the top of the mark if the cursor is in the middle of the mark', function()
      local selected = 2
      local mark = marks[selected]
      for i = mark.top + 1, mark.bot do
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ i, 0 })
        eq(navigation.up(window, marks), selected)
      end
    end)
    a.it('should jump to the top of the mark if the cursor is in the end of the mark', function()
      local selected = 2
      local mark = marks[selected]
      for i = mark.bot - 1, mark.top + 1, -1 do
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ i, 0 })
        eq(navigation.up(window, marks), selected)
      end
    end)
    a.it('should jump to the end of the previous mark if the cursor is in the top of the current mark', function()
      local selected = 2
      local mark = marks[selected]
      vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
      vim.api.nvim_win_get_cursor.returns({ mark.top, 0 })
      eq(navigation.up(window, marks), selected - 1)
    end)
  end)

  a.describe('down', function()
    a.it('should select the first mark when the cursor on the end of last mark', function()
      local mark = marks[#marks]
      vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
      vim.api.nvim_win_get_cursor.returns({ mark.bot, 0 })
      eq(navigation.down(window, marks), 1)
    end)
    a.it('should select the second mark if the user is on the end of the first mark', function()
      vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
      vim.api.nvim_win_get_cursor.returns({ marks[2].top, 0 })
      eq(navigation.down(window, marks), 2)
    end)
    a.it('should jump to the end of the mark if the cursor is in the middle of the mark', function()
      local selected = 1
      local mark = marks[selected]
      for i = mark.top, mark.bot - 1 do
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ i, 0 })
        eq(navigation.down(window, marks), selected)
      end
    end)
    a.it('should jump to the end of the mark if the cursor is on top of the mark', function()
      local selected = 1
      local mark = marks[selected]
      vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
      vim.api.nvim_win_get_cursor.returns({ mark.top, 0 })
      eq(navigation.down(window, marks), selected)
    end)
  end)
end)
