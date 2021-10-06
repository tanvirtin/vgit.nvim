local Object = require('plenary.class')
local autocmd = require('vgit.autocmd')
local buffer = require('vgit.buffer')

local VirtualLineNrDecorator = Object:extend()

function VirtualLineNrDecorator:new(config, window_props, content_buf)
  return setmetatable({
    buf = nil,
    win_id = nil,
    ns_id = nil,
    config = config,
    content_buf = content_buf,
    window_props = window_props,
  }, VirtualLineNrDecorator)
end

function VirtualLineNrDecorator:mount()
  self.buf = vim.api.nvim_create_buf(false, true)
  buffer.assign_options(self.buf, {
    ['modifiable'] = false,
    ['bufhidden'] = 'wipe',
    ['buflisted'] = false,
  })
  self.win_id = vim.api.nvim_open_win(self.buf, false, {
    relative = 'editor',
    style = 'minimal',
    focusable = false,
    row = self.window_props.row,
    col = self.window_props.col,
    height = self.window_props.height,
    width = self.config.width,
  })
  vim.api.nvim_win_set_option(self.win_id, 'cursorbind', true)
  vim.api.nvim_win_set_option(self.win_id, 'scrollbind', true)
  vim.api.nvim_win_set_option(self.win_id, 'winhl', 'Normal:')
  self.ns_id = vim.api.nvim_create_namespace(
    string.format(
      'tanvirtin/vgit.nvim/virtual_line_nr/%s/%s',
      self.buf,
      self.win_id
    )
  )
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

function VirtualLineNrDecorator:get_win_id()
  return self.win_id
end

function VirtualLineNrDecorator:get_buf()
  return self.buf
end

function VirtualLineNrDecorator:set_lines(lines)
  buffer.set_lines(self.buf, lines)
  return self
end

function VirtualLineNrDecorator:set_hls(hls)
  for i = 1, #hls do
    vim.api.nvim_buf_add_highlight(self.buf, -1, hls[i], i - 1, 0, -1)
  end
  return self
end

function VirtualLineNrDecorator:unmount()
  vim.api.nvim_win_close(self:get_win_id(), true)
  return self
end

return VirtualLineNrDecorator
