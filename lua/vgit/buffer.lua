local buffer_store = require('vgit.stores.buffer_store')

local M = {}

M.store = buffer_store

M.current = function()
  return vim.api.nvim_get_current_buf()
end

M.add_keymap = function(buf, key, action)
  vim.api.nvim_buf_set_keymap(
    buf,
    'n',
    key,
    string.format(':lua require("vgit").%s<CR>', action),
    {
      silent = true,
      noremap = true,
    }
  )
end

M.remove_keymap = function(buf, key)
  vim.api.nvim_buf_del_keymap(buf, 'n', key)
end

M.get_lines = function(buf, start, finish)
  start = start or 0
  finish = finish or -1
  return vim.api.nvim_buf_get_lines(buf, start, finish, false)
end

M.set_lines = function(buf, lines, start, finish)
  start = start or 0
  finish = finish or -1
  local modifiable = vim.api.nvim_buf_get_option(buf, 'modifiable')
  if modifiable then
    vim.api.nvim_buf_set_lines(buf, start, finish, false, lines)
    return
  end
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, start, finish, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

M.set_option = function(buf, key, value)
  vim.api.nvim_buf_set_option(buf, key, value)
end

M.get_option = function(buf, key)
  return vim.api.nvim_buf_get_option(buf, key)
end

M.assign_options = function(buf, options)
  for key, value in pairs(options) do
    vim.api.nvim_buf_set_option(buf, key, value)
  end
end

M.is_being_edited = function(buf)
  return M.get_option(buf, 'modified')
end

M.is_valid = function(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)
end

M.list = vim.api.nvim_list_bufs

return M
