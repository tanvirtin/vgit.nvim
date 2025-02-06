local Object = require('vgit.core.Object')
local assertion = require('vgit.core.assertion')

local Window = Object:extend()

function Window:constructor(win_id)
  assertion.assert_number(win_id)
  if win_id == 0 then win_id = vim.api.nvim_get_current_win() end
  return { win_id = win_id }
end

function Window:open(buffer, opts)
  if not buffer then error('buffer is required') end

  opts = opts or {}
  local focus = opts.focus

  if opts.focus ~= nil then opts.focus = nil end

  local win_id = vim.api.nvim_open_win(buffer.bufnr, focus ~= nil and focus or false, opts)

  return Window(win_id)
end

function Window:get_cursor()
  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, self.win_id)
  if not ok or not cursor then return { 1, 1 } end

  return cursor
end

function Window:get_lnum()
  return self:get_cursor()[1]
end

function Window:get_position()
  return vim.api.nvim_win_get_position(self.win_id)
end

function Window:get_height()
  return vim.api.nvim_win_get_height(self.win_id)
end

function Window:get_width()
  return vim.api.nvim_win_get_width(self.win_id)
end

function Window:set_cursor(cursor)
  return self:call(function()
    pcall(vim.api.nvim_win_set_cursor, self.win_id, cursor)
  end)
end

function Window:set_lnum(lnum)
  local cursor = self:get_cursor()
  return self:set_cursor({ lnum, cursor[2] })
end

function Window:set_option(key, value)
  pcall(vim.api.nvim_win_set_option, self.win_id, key, value)
  return self
end

function Window:set_height(height)
  vim.api.nvim_win_set_height(self.win_id, height)
  return self
end

function Window:set_width(width)
  vim.api.nvim_win_set_width(self.win_id, width)
  return self
end

function Window:set_win_plot(win_plot)
  if win_plot.focus ~= nil then win_plot.focus = nil end
  vim.api.nvim_win_set_config(self.win_id, win_plot)
  return self
end

function Window:get_win_plot()
  return vim.api.nvim_win_get_config(self.win_id)
end

function Window:assign_options(options)
  for key, value in pairs(options) do
    vim.api.nvim_win_set_option(self.win_id, key, value)
  end
  return self
end

function Window:is_valid()
  return vim.api.nvim_win_is_valid(self.win_id)
end

function Window:close()
  pcall(vim.api.nvim_win_hide, self.win_id)
  return self
end

function Window:is_focused()
  return self.win_id == vim.api.nvim_get_current_win()
end

function Window:focus()
  vim.api.nvim_set_current_win(self.win_id)
  return self
end

function Window:is_same(window)
  return self.win_id == window.win_id
end

function Window:position_cursor(placement)
  local placement_map = {
    top = function()
      vim.cmd('norm! zt')
    end,
    center = function()
      vim.cmd('norm! zz')
    end,
    bottom = function()
      vim.cmd('norm! zb')
    end,
  }

  placement = placement or 'center'

  return self:call(placement_map[placement])
end

function Window:call(callback)
  pcall(vim.api.nvim_win_call, self.win_id, callback)
  return self
end

return Window
