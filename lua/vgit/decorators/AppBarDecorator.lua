local Object = require('plenary.class')
local autocmd = require('vgit.autocmd')
local buffer = require('vgit.buffer')
local virtual_text = require('vgit.virtual_text')
local render_store = require('vgit.stores.render_store')
local AppBarDecorator = Object:extend()

local config = render_store.get('layout').decorator

function AppBarDecorator:new(window_props, content_buf)
  return setmetatable({
    buf = nil,
    win_id = nil,
    content_buf = content_buf,
    window_props = window_props,
    ns_id = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/AppBarDecorator'),
  }, AppBarDecorator)
end

function AppBarDecorator:make_border(c)
  if c.hl then
    local new_border = {}
    for _, char in pairs(c.chars) do
      if type(char) == 'table' then
        char[2] = c.hl
        new_border[#new_border + 1] = char
      else
        new_border[#new_border + 1] = { char, c.hl }
      end
    end
    return new_border
  end
  return c.chars
end

function AppBarDecorator:mount()
  self.buf = vim.api.nvim_create_buf(true, true)
  buffer.assign_options(self.buf, {
    ['modifiable'] = false,
    ['bufhidden'] = 'wipe',
    ['buflisted'] = false,
  })
  self.win_id = vim.api.nvim_open_win(self.buf, false, {
    border = self:make_border(config.app_bar.border),
    style = 'minimal',
    focusable = false,
    relative = self.window_props.relative,
    row = self.window_props.row,
    col = self.window_props.col,
    width = self.window_props.width - 2,
    height = 1,
    zindex = 100,
  })
  vim.api.nvim_win_set_option(self.win_id, 'cursorbind', false)
  vim.api.nvim_win_set_option(self.win_id, 'scrollbind', false)
  vim.api.nvim_win_set_option(self.win_id, 'winhl', 'Normal:')
  autocmd.buf.on(
    self.content_buf,
    'WinClosed',
    string.format(
      ':lua _G.package.loaded.vgit.renderer.hide_windows({ %s })',
      self.win_id
    ),
    { once = true }
  )
  return self
end

function AppBarDecorator:get_win_id()
  return self.win_id
end

function AppBarDecorator:get_buf()
  return self.buf
end

function AppBarDecorator:get_ns_id()
  return self.ns_id
end

function AppBarDecorator:get_lines()
  return buffer.get_lines(self:get_buf())
end

function AppBarDecorator:set_lines(lines)
  assert(vim.tbl_islist(lines), 'type error :: expected list table')
  buffer.set_lines(self:get_buf(), lines)
  return self
end

function AppBarDecorator:transpose_text(text, row, col, pos)
  assert(vim.tbl_islist(text), 'type error :: expected list table')
  assert(#text == 2, 'invalid number of text entries')
  assert(type(row) == 'number', 'type error :: expected number')
  assert(type(col) == 'number', 'type error :: expected number')
  virtual_text.transpose_text(
    self:get_buf(),
    text[1],
    self:get_ns_id(),
    text[2],
    row,
    col,
    pos
  )
  return self
end

function AppBarDecorator:clear_ns_id()
  virtual_text.clear(self:get_buf(), self:get_ns_id())
  return self
end

return AppBarDecorator
