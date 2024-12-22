local fs = require('vgit.core.fs')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local keymap = require('vgit.core.keymap')
local renderer = require('vgit.core.renderer')
local Namespace = require('vgit.core.Namespace')

local Buffer = Object:extend()

function Buffer:constructor(bufnr)
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  return {
    bufnr = bufnr,
    rendering = false,
    namespace = Namespace(),
    state = {
      is_processing = false,
      is_attached_to_screen = false,
      on_render = function() end,
    },
  }
end

function Buffer:call(callback)
  vim.api.nvim_buf_call(self.bufnr, callback)

  return self
end

function Buffer:attach_to_changes(opts)
  vim.api.nvim_buf_attach(self.bufnr, false, opts)

  return self
end

function Buffer:attach_to_renderer(on_render)
  -- Method to inject on_render logic and only state it.
  -- This allows us to change rendering logic during run time.
  local state = self.state
  state.on_render = on_render

  if not state.is_attached_to_screen then
    renderer.attach(self)
    state.is_attached_to_screen = true
  end

  return self
end

function Buffer:detach_from_renderer()
  renderer.detach(self)

  return self
end

function Buffer:on(event_type, callback)
  event.buffer_on(self, event_type, callback)

  return self
end

function Buffer:on_render(top, bot)
  self.state.on_render(top, bot)

  return self
end

function Buffer:is_in_disk()
  return fs.exists(self:get_name())
end

function Buffer:sync()
  return self
end

function Buffer:get_name()
  return vim.api.nvim_buf_get_name(self.bufnr)
end

function Buffer:add_highlight(opts)
  return self.namespace:add_highlight(self, {
    hl = opts.hl,
    row = opts.row,
    col_range = {
      from = opts.col_range.from,
      to = opts.col_range.to,
    },
  })
end

function Buffer:add_pattern_highlight(pattern, hl)
  return self.namespace:add_pattern_highlight(self, pattern, hl)
end

function Buffer:sign_place(lnum, sign_name)
  return self.namespace:sign_place(self, lnum, sign_name)
end

function Buffer:sign_placelist(signs)
  for _, sign in ipairs(signs) do
    self.namespace:virtual_sign_place(self, sign.lnum, sign.name)
  end

  return self
end

function Buffer:sign_unplace()
  local count = self:get_line_count()

  for lnum = 1, count  do
    self.namespace:virtual_sign_unplace(self, lnum)
  end

  return self
end

function Buffer:transpose_virtual_text(opts)
  return self.namespace:transpose_virtual_text(self, {
    text = opts.text,
    hl = opts.hl,
    row = opts.row,
    col = opts.col,
    pos = opts.pos,
    priority = opts.priority,
  })
end

function Buffer:transpose_virtual_line(opts)
  return self.namespace:transpose_virtual_line(self, {
    texts = opts.texts,
    row = opts.row,
    pos = opts.pos,
    priority = opts.priority,
  })
end

function Buffer:transpose_virtual_line_number(opts)
  return self.namespace:transpose_virtual_line_number(self, {
    row = opts.row,
    hl = opts.hl,
    text = opts.text,
  })
end

function Buffer:insert_virtual_line(opts)
  return self.namespace:insert_virtual_line(self, {
    text = opts.text,
    hl = opts.hl,
    row = opts.row,
    priority = opts.priority,
  })
end

function Buffer:clear_namespace()
  return self.namespace:clear(self)
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

function Buffer:get_lines(top, bot)
  top = top or 0
  bot = bot or -1

  return vim.api.nvim_buf_get_lines(self.bufnr, top, bot, false)
end

function Buffer:get_option(key)
  return vim.api.nvim_buf_get_option(self.bufnr, key)
end

function Buffer:set_lines(lines, top, bot)
  top = top or 0
  bot = bot or -1
  local bufnr = self.bufnr
  local modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')

  if modifiable then
    pcall(vim.api.nvim_buf_set_lines, bufnr, top, bot, false, lines)
    return self
  end

  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  pcall(vim.api.nvim_buf_set_lines, bufnr, top, bot, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

  return self
end

function Buffer:set_option(key, value)
  pcall(vim.api.nvim_buf_set_option, self.bufnr, key, value)

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

function Buffer:edit()
  return self:call(function()
    local v = vim.fn.winsaveview()

    vim.cmd('edit')
    vim.fn.winrestview(v)
  end)
end

function Buffer:editing()
  return self:get_option('modified')
end

function Buffer:filetype()
  return fs.detect_filetype(self:get_name())
end

function Buffer:list()
  local bufnrs = vim.api.nvim_list_bufs()
  local buffers = {}

  for i = 1, #bufnrs do
    buffers[#buffers + 1] = Buffer(bufnrs[i])
  end

  return buffers
end

function Buffer:set_keymap(mode, key, callback)
  keymap.buffer_set(self, mode, key, callback)

  return self
end

function Buffer:set_var(name, value)
  vim.api.nvim_buf_set_var(self.bufnr, name, value)

  return self
end

return Buffer
