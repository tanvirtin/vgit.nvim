local a = require('plenary.async.tests')
local Window = require('vgit.core.Window')
local mock = require('luassert.mock')

local describe = describe
local it = it
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

a.describe('Window:', function()
  local cursor = { 10, 2 }
  before_each(function()
    vim.api.nvim_win_set_cursor = mock(vim.api.nvim_win_set_cursor, true)
    vim.api.nvim_win_get_cursor = mock(vim.api.nvim_win_get_cursor, true)
    vim.api.nvim_win_get_cursor.returns(cursor)
  end)

  after_each(function()
    mock.revert(vim.api.nvim_win_set_cursor)
    mock.revert(vim.api.nvim_win_get_cursor)
  end)

  a.describe('new', function()
    a.it(
      'should throw an error no win_id is provided to construct the window',
      function()
        assert.has_error(function()
          Window:new()
        end)
      end
    )
    a.it(
      'should create an instance of the window object binding the win_id',
      function()
        local win_id = vim.api.nvim_open_win(
          vim.api.nvim_create_buf(false, false),
          false,
          { relative = 'win', row = 3, col = 3, width = 12, height = 3 }
        )
        local window = Window:new(win_id)
        eq(window:is(Window), true)
      end
    )
    a.it(
      'should create a window object binding the current win_id if the win_id is 0',
      function()
        local win_id = vim.api.nvim_get_current_win()
        local window = Window:new(0)
        eq(window:is(Window), true)
        eq(window.win_id, win_id)
      end
    )
  end)

  describe('set_cursor', function()
    local window
    local win_id
    local cursor

    before_each(function()
      cursor = { 1, 1 }
      win_id = vim.api.nvim_open_win(
        vim.api.nvim_create_buf(false, false),
        false,
        { relative = 'win', row = 3, col = 3, width = 12, height = 3 }
      )
      window = Window:new(win_id)
    end)

    a.it('should call nvim_win_set_cursor using the bounded win_id', function()
      window:set_cursor(cursor)
      assert.stub(vim.api.nvim_win_set_cursor).was_called_with(win_id, cursor)
    end)
  end)

  describe('get_cursor', function()
    local window
    local win_id

    before_each(function()
      win_id = vim.api.nvim_open_win(
        vim.api.nvim_create_buf(false, false),
        false,
        { relative = 'win', row = 3, col = 3, width = 12, height = 3 }
      )
      window = Window:new(win_id)
    end)

    a.it('should call nvim_win_set_cursor using the bounded win_id', function()
      local returned_cursor = window:get_cursor()
      eq(cursor, returned_cursor)
    end)

    a.it('should return the lnum from the current cursor', function()
      local lnum = window:get_lnum()
      eq(lnum, 10)
    end)

    a.it('should set the current lnum', function()
      window:set_lnum(111)
      assert.stub(vim.api.nvim_win_set_cursor).was_called_with(
        win_id,
        { 111, cursor[2] }
      )
    end)
  end)
end)
