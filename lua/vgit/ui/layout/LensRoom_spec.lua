local eq = assert.are.same

describe('LensRoom:', function()
  local LensRoom
  local win_id, bufnr, lines, columns

  local function marks()
    return vim.api.nvim_buf_get_extmarks(bufnr, LensRoom.NAMESPACE, 0, -1, { details = true })
  end

  local function winline()
    return vim.api.nvim_win_call(win_id, function()
      return vim.fn.winline()
    end)
  end

  before_each(function()
    LensRoom = require('vgit.ui.layout.LensRoom')
    columns, lines = vim.o.columns, vim.o.lines
    vim.o.columns, vim.o.lines = 120, 40
    vim.cmd('silent! tabonly!')
    vim.cmd('silent! only!')
    vim.cmd('enew!')

    win_id = vim.api.nvim_get_current_win()
    bufnr = vim.api.nvim_get_current_buf()

    local text = {}

    for i = 1, 100 do
      text[i] = 'line ' .. i
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
    vim.wo.scrolloff = 0
    vim.wo.wrap = false
    vim.cmd('redraw')
  end)

  after_each(function()
    vim.api.nvim_buf_clear_namespace(bufnr, LensRoom.NAMESPACE, 0, -1)
    vim.o.columns, vim.o.lines = columns, lines
  end)

  describe('reserve', function()
    it('should put blank virtual lines under the cursor line', function()
      vim.api.nvim_win_set_cursor(win_id, { 10, 0 })

      local room = LensRoom.reserve(win_id, 6)
      local mark = marks()[1]

      eq(1, #marks())
      eq(9, mark[2])
      eq(6, #mark[4].virt_lines)
      eq(false, mark[4].virt_lines_above)
      eq(6, room.height)
    end)

    it('should report the row just under the cursor line, in the window it belongs to', function()
      vim.api.nvim_win_set_cursor(win_id, { 10, 0 })
      vim.cmd('redraw')

      local room = LensRoom.reserve(win_id, 6)

      eq(vim.api.nvim_win_get_position(win_id)[1] + winline(), room.row)
    end)

    it('should follow a window that is not at the top-left of the editor', function()
      vim.cmd('botright vsplit')
      win_id = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win_id, bufnr)
      vim.api.nvim_win_set_cursor(win_id, { 10, 0 })
      vim.cmd('redraw')

      local room = LensRoom.reserve(win_id, 6)

      assert.is_true(room.col > 0)
      eq(vim.api.nvim_win_get_width(win_id), room.width)
      eq(vim.api.nvim_win_get_position(win_id)[2], room.col)
    end)

    it('should scroll just enough to keep the room on screen near the bottom of the window', function()
      local height = vim.api.nvim_win_get_height(win_id)

      vim.cmd('normal! 1Gzt')
      vim.api.nvim_win_set_cursor(win_id, { height - 1, 0 })
      vim.cmd('redraw')

      local before = winline()
      local room = LensRoom.reserve(win_id, 8)

      assert.is_true(height - winline() >= room.height)
      assert.is_true(winline() < before)
      eq(height - 1, vim.api.nvim_win_get_cursor(win_id)[1])
    end)

    it('should not scroll when there is already room', function()
      vim.api.nvim_win_set_cursor(win_id, { 3, 0 })
      vim.cmd('redraw')

      local before = vim.fn.winsaveview().topline

      LensRoom.reserve(win_id, 6)

      eq(before, vim.fn.winsaveview().topline)
    end)

    it('should never ask for more than the window can show', function()
      local room = LensRoom.reserve(win_id, 500)

      eq(vim.api.nvim_win_get_height(win_id) - 1, room.height)
    end)

    it('should work on the last line of the buffer', function()
      vim.api.nvim_win_set_cursor(win_id, { 100, 0 })
      vim.cmd('redraw')

      local room = LensRoom.reserve(win_id, 6)

      eq(99, marks()[1][2])
      eq(6, room.height)
    end)
  end)

  describe('release', function()
    it('should give the room back', function()
      local room = LensRoom.reserve(win_id, 6)

      LensRoom.release(room)

      eq(0, #marks())
    end)

    it('should accept nothing, and a room whose buffer is gone', function()
      LensRoom.release(nil)

      local other = vim.api.nvim_create_buf(false, true)
      local room = { bufnr = other, mark = 1 }

      vim.api.nvim_buf_delete(other, { force = true })
      LensRoom.release(room)
    end)
  end)
end)
