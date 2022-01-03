local Namespace = require('vgit.core.Namespace')
local keymap = require('vgit.core.keymap')
local GitObject = require('vgit.core.GitObject')
local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')

local Buffer = Object:extend()

function Buffer:new(bufnr)
  local filename = nil
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    filename = fs.relative_filename(bufname)
  end
  return setmetatable({
    bufnr = bufnr,
    filename = filename,
    watcher = nil,
    git_object = nil,
    namespace = Namespace:new(),
  }, Buffer)
end

function Buffer:get_name()
  return vim.api.nvim_buf_get_name(self.bufnr)
end

function Buffer:add_highlight(hl, row, col_start, col_end)
  self.namespace:add_highlight(self, hl, row, col_start, col_end)
  return self
end

function Buffer:sign_place(lnum, sign_definition)
  self.namespace:sign_place(self, lnum, sign_definition)
  return self
end

function Buffer:sign_unplace()
  self.namespace:sign_unplace(self)
  return self
end

function Buffer:transpose_virtual_text(text, hl, row, col, pos)
  self.namespace:transpose_virtual_text(self, text, hl, row, col, pos)
  return self
end

function Buffer:transpose_virtual_line(texts, col, pos)
  self.namespace:transpose_virtual_line(self, texts, col, pos)
  return self
end

function Buffer:clear_namespace()
  self.namespace:clear(self)
  return self
end

function Buffer:sync()
  local bufname = vim.api.nvim_buf_get_name(self.bufnr)
  self.filename = fs.relative_filename(bufname)
  self.git_object = GitObject:new(self.filename)
  return self
end

function Buffer:sync_git()
  self.git_object = GitObject:new(self.filename)
  return self
end

function Buffer:create(listed, scratch)
  listed = listed == nil and false or listed
  scratch = scratch == nil and true or scratch
  self.bufnr = vim.api.nvim_create_buf(listed, scratch)
  return self
end

function Buffer:is_current()
  return self.bufnr == vim.api.nvim_get_current_buf()
end

function Buffer:is_valid()
  local bufnr = self.bufnr
  return vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)
end

function Buffer:delete(opts)
  opts = opts or {}
  vim.tbl_extend('keep', opts, { force = true })
  vim.api.nvim_buf_delete(self.bufnr, opts)
  return self
end

function Buffer:get_lines(start, finish)
  start = start or 0
  finish = finish or -1
  return vim.api.nvim_buf_get_lines(self.bufnr, start, finish, false)
end

function Buffer:get_option(key)
  return vim.api.nvim_buf_get_option(self.bufnr, key)
end

function Buffer:set_lines(lines, start, finish)
  start = start or 0
  finish = finish or -1
  local bufnr = self.bufnr
  local modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
  if modifiable then
    vim.api.nvim_buf_set_lines(bufnr, start, finish, false, lines)
    return
  end
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, start, finish, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  return self
end

function Buffer:set_option(key, value)
  vim.api.nvim_buf_set_option(self.bufnr, key, value)
  return self
end

function Buffer:assign_options(options)
  local bufnr = self.bufnr
  for key, value in pairs(options) do
    vim.api.nvim_buf_set_option(bufnr, key, value)
  end
  return self
end

function Buffer:get_line_count()
  return vim.api.nvim_buf_line_count(self.bufnr)
end

function Buffer:editing()
  return self:get_option('modified')
end

function Buffer:filetype()
  return fs.detect_filetype(self.filename)
end

function Buffer:list()
  local bufnrs = vim.api.nvim_list_bufs()
  local buffers = {}
  for i = 1, #bufnrs do
    buffers[#buffers + 1] = Buffer:new(bufnrs[i])
  end
  return buffers
end

function Buffer:set_keymap(mode, key, action)
  keymap.buffer_set(self, mode, key, action)
  return self
end

function Buffer:attach(opts)
  vim.api.nvim_buf_attach(self.bufnr, false, opts)
  return self
end

return Buffer
