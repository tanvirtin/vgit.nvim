local LensRoom = {}

LensRoom.NAMESPACE = vim.api.nvim_create_namespace('vgit_lens_room')

local function cursor_row(win_id)
  return vim.api.nvim_win_call(win_id, function()
    return vim.fn.winline()
  end)
end

local function first_row_under(win_id, line, bufnr)
  local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
  local pos = vim.fn.screenpos(win_id, line, math.max(#text, 1))

  if pos.row > 0 then return pos.row end

  local top = vim.api.nvim_win_get_position(win_id)[1]
  local winbar = vim.api.nvim_get_option_value('winbar', { win = win_id }) ~= '' and 1 or 0

  return top + winbar + cursor_row(win_id)
end

function LensRoom.reserve(win_id, requested)
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local window_height = vim.api.nvim_win_get_height(win_id)
  local height = math.max(1, math.min(requested or window_height - 1, window_height - 1))
  local line = vim.api.nvim_win_get_cursor(win_id)[1]

  local blank = {}

  for i = 1, height do
    blank[i] = { { '' } }
  end

  local mark = vim.api.nvim_buf_set_extmark(bufnr, LensRoom.NAMESPACE, line - 1, 0, {
    virt_lines = blank,
    virt_lines_above = false,
  })

  vim.api.nvim_win_call(win_id, function()
    local guard = window_height

    while guard > 0 and window_height - vim.fn.winline() < height and vim.fn.winline() > 1 do
      vim.cmd('normal! \5')
      guard = guard - 1
    end
  end)

  return {
    bufnr = bufnr,
    mark = mark,
    row = first_row_under(win_id, line, bufnr),
    col = vim.api.nvim_win_get_position(win_id)[2],
    width = vim.api.nvim_win_get_width(win_id),
    height = height,
  }
end

function LensRoom.release(room)
  if not room then return end

  pcall(vim.api.nvim_buf_del_extmark, room.bufnr, LensRoom.NAMESPACE, room.mark)
end

return LensRoom
