local renderer = require('vgit.core.renderer')
local loop = require('vgit.core.loop')
local console = require('vgit.core.console')
local Namespace = require('vgit.core.Namespace')
local signs_setting = require('vgit.settings.signs')
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
    rendering = false,
    file_watcher = nil,
    git_object = nil,
    namespace = Namespace:new(),
    state = {
      is_attached_to_screen = false,
      on_render = function() end,
      live_signs = {},
    },
  }, Buffer)
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

function Buffer:on_render(top, bot)
  -- We invoke the render function called on runtime.
  self.state.on_render(top, bot)
  return self
end

function Buffer:is_rendering()
  return self.rendering
end

function Buffer:set_cached_live_signs(live_signs)
  self.state.live_signs = live_signs
  return self
end

function Buffer:clear_cached_live_signs()
  self.state.live_signs = {}
  return self
end

function Buffer:get_cached_live_signs()
  return self.state.live_signs
end

function Buffer:cache_live_sign(hunk)
  local bufnr = self.bufnr
  local live_signs = self:get_cached_live_signs()
  local sign_priority = signs_setting:get('priority')
  local sign_group = self.namespace:sign_ns_id(self)
  local sign_types = signs_setting:get('usage').main
  for j = hunk.top, hunk.bot do
    local lnum = (hunk.type == 'remove' and j == 0) and 1 or j
    live_signs[lnum] = {
      id = lnum,
      lnum = lnum,
      buffer = bufnr,
      group = sign_group,
      name = sign_types[hunk.type],
      priority = sign_priority,
    }
  end
  return self
end

function Buffer:watch_file(callback)
  self.file_watcher = loop.watch(
    self.filename,
    loop.async(function(err)
      if err then
        console.debug(
          string.format('Error encountered while watching %s', self.filename)
        )
        return
      end
      loop.await_fast_event()
      if self and self:is_valid() and callback then
        callback()
      end
    end)
  )
  return self
end

function Buffer:unwatch_file()
  loop.unwatch(self.file_watcher)
  return self
end

function Buffer:get_name()
  return vim.api.nvim_buf_get_name(self.bufnr)
end

function Buffer:add_highlight(hl, row, col_top, col_end)
  self.namespace:add_highlight(self, hl, row, col_top, col_end)
  return self
end

function Buffer:sign_place(lnum, sign_name)
  self.namespace:sign_place(self, lnum, sign_name)
  return self
end

function Buffer:sign_placelist(signs)
  vim.fn.sign_placelist(signs)
  return self
end

function Buffer:sign_unplace()
  self.namespace:sign_unplace(self)
  return self
end

function Buffer:transpose_virtual_text(text, hl, row, col, pos, priority)
  self.namespace:transpose_virtual_text(self, text, hl, row, col, pos, priority)
  return self
end

function Buffer:transpose_virtual_line(texts, col, pos, priority)
  self.namespace:transpose_virtual_line(self, texts, col, pos, priority)
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
  -- TODO: Log this error in the future
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

return Buffer
