local a = require('plenary.async.tests')
local mock = require('luassert.mock')
local Window = require('vgit.core.Window')
local Navigation = require('vgit.Navigation')

local describe = describe
local it = it
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

a.describe('Navigation:', function()
  local win_id = 1
  local window = Window:new(0)
  local navigation
  local hunks = {
    {
      start = 30,
      finish = 40,
    },
    {
      start = 50,
      finish = 60,
    },
    {
      start = 65,
      finish = 95,
    },
    {
      start = 95,
      finish = 105,
    },
    {
      start = 300,
      finish = 400,
    },
    {
      start = 410,
      finish = 410,
    },
  }

  before_each(function()
    navigation = Navigation:new()
    vim.api.nvim_win_set_cursor = mock(vim.api.nvim_win_set_cursor, true)
  end)
  after_each(function()
    mock.revert(vim.api.nvim_win_set_cursor)
  end)

  a.describe('new', function()
    a.it('should create an instance of the command object', function()
      eq(navigation:is(Navigation), true)
    end)
  end)

  a.describe('hunk_up', function()
    a.it(
      'should select the last hunk when the cursor is above the first hunk',
      function()
        for i = 1, hunks[1].start do
          vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
          vim.api.nvim_win_get_cursor.returns({ i, 0 })
          eq(navigation:hunk_up(window, hunks), #hunks)
        end
      end
    )
    a.it(
      'should select the second last hunk if the cursor is inside the last hunk',
      function()
        for i = hunks[#hunks].start, hunks[#hunks - 1].finish, -1 do
          vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
          vim.api.nvim_win_get_cursor.returns({ i, 0 })
          eq(navigation:hunk_up(window, hunks), #hunks - 1)
        end
      end
    )
    a.it(
      'should jump to the start of the hunk if the cursor is in the middle of the hunk',
      function()
        local selected = 2
        local hunk = hunks[selected]
        for i = hunk.start + 1, hunk.finish do
          vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
          vim.api.nvim_win_get_cursor.returns({ i, 0 })
          eq(navigation:hunk_up(window, hunks), selected)
        end
      end
    )
    a.it(
      'should jump to the start of the hunk if the cursor is in the end of the hunk',
      function()
        local selected = 2
        local hunk = hunks[selected]
        for i = hunk.finish - 1, hunk.start + 1, -1 do
          vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
          vim.api.nvim_win_get_cursor.returns({ i, 0 })
          eq(navigation:hunk_up(window, hunks), selected)
        end
      end
    )
    a.it(
      'should jump to the end of the previous hunk if the cursor is in the start of the current hunk',
      function()
        local selected = 2
        local hunk = hunks[selected]
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ hunk.start, 0 })
        eq(navigation:hunk_up(window, hunks), selected - 1)
      end
    )
  end)

  a.describe('hunk_down', function()
    a.it(
      'should select the first hunk when the cursor on the end of last hunk',
      function()
        local hunk = hunks[#hunks]
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ hunk.finish, 0 })
        eq(navigation:hunk_down(window, hunks), 1)
      end
    )
    a.it(
      'should select the second hunk if the user is on the end of the first hunk',
      function()
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ hunks[2].start, 0 })
        eq(navigation:hunk_down(window, hunks), 2)
      end
    )
    a.it(
      'should jump to the end of the hunk if the cursor is in the middle of the hunk',
      function()
        local selected = 1
        local hunk = hunks[selected]
        for i = hunk.start, hunk.finish - 1 do
          vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
          vim.api.nvim_win_get_cursor.returns({ i, 0 })
          eq(navigation:hunk_down(window, hunks), selected)
        end
      end
    )
    a.it(
      'should jump to the end of the hunk if the cursor is on top of the hunk',
      function()
        local selected = 1
        local hunk = hunks[selected]
        vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
        vim.api.nvim_win_get_cursor.returns({ hunk.start, 0 })
        eq(navigation:hunk_down(window, hunks), selected)
      end
    )
  end)
end)
