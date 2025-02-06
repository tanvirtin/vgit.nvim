local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local Extmark = require('vgit.ui.Extmark')
local Object = require('vgit.core.Object')
local keymap = require('vgit.core.keymap')
local renderer = require('vgit.core.renderer')

local Buffer = Object:extend()

function Buffer:constructor(bufnr)
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  return {
    bufnr = bufnr,
    on_render = function() end,
    is_attached_to_screen = false,
    text_extmark = Extmark(bufnr, 'text'),
    lnum_extmark = Extmark(bufnr, 'lnum'),
    sign_extmark = Extmark(bufnr, 'sign'),
    highlight_extmark = Extmark(bufnr, 'highlight'),
  }
end

function Buffer:sync()
  return self
end

function Buffer:set_state(state)
  for key, value in pairs(state) do
    self.state[key] = value
  end
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
  self.on_render = on_render or function() end

  if not self.is_attached_to_screen then
    renderer.attach(self)
    self.is_attached_to_screen = true
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

function Buffer:render(top, bot)
  self.on_render(top, bot)
  return self
end

function Buffer:is_in_disk()
  return self:is_valid() and fs.exists(self:get_name())
end

function Buffer:get_name()
  return vim.api.nvim_buf_get_name(self.bufnr)
end

function Buffer:get_relative_name()
  local name = self:get_name()
  if not name and name == '' then return name end
  return fs.relative_filename(name)
end

function Buffer:place_extmark_text(opts)
  return self.text_extmark:text(opts)
end

function Buffer:place_extmark_sign(opts)
  return self.sign_extmark:sign(opts)
end

function Buffer:place_extmark_lnum(opts)
  return self.lnum_extmark:lnum(opts)
end

function Buffer:place_extmark_highlight(opts)
  return self.highlight_extmark:highlight(opts)
end

function Buffer:clear_extmark_texts()
  loop.free_textlock()
  if not self:is_valid() then return end
  return self.text_extmark:clear()
end

function Buffer:clear_extmark_lnums()
  return self.lnum_extmark:clear()
end

function Buffer:clear_extmark_signs()
  return self.sign_extmark:clear()
end

function Buffer:clear_extmark_highlights()
  self.highlight_extmark:clear()
  return self
end

function Buffer:clear_extmarks()
  self:clear_extmark_texts()
  self:clear_extmark_lnums()
  self:clear_extmark_signs()
  self:clear_extmark_highlights()

  return self
end

function Buffer:create(listed, scratch)
  listed = listed == nil and false or listed
  scratch = scratch == nil and true or scratch
  local bufnr = vim.api.nvim_create_buf(listed, scratch)

  self.bufnr = bufnr
  self.text_extmark = Extmark(bufnr, 'text')
  self.lnum_extmark = Extmark(bufnr, 'lnum')
  self.sign_extmark = Extmark(bufnr, 'sign')
  self.highlight_extmark = Extmark(bufnr, 'highlight')

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

function Buffer:set_option(key, value)
  pcall(vim.api.nvim_buf_set_option, self.bufnr, key, value)
  return self
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

  self:set_option('modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, top, bot, false, lines)
  self:set_option('modifiable', false)

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
  return fs.detect_filetype(self:get_name())
end

function Buffer:set_keymap(opts, callback)
  keymap.buffer_set(self, opts, callback)
  return self
end

function Buffer:set_var(name, value)
  vim.api.nvim_buf_set_var(self.bufnr, name, value)
  return self
end

return Buffer
