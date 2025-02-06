local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local dimensions = require('vgit.ui.dimensions')

local Split = Component:extend()

function Split:constructor(props)
  props = utils.object.assign({
    buffer = nil,
    window = nil,
    state = {},
    config = {
      elements = {},
      height = 20,
      width = '100vw',
      buf_options = {
        modifiable = false,
        buflisted = false,
        bufhidden = 'wipe',
      },
      win_options = {
        winhl = 'Normal:GitBackground',
        signcolumn = 'no',
        wrap = false,
        number = false,
        cursorline = false,
        statusline = ' ',
      },
      locked = false,
      focus = true,
      position = 'bottom',
    },
    mounted = false,
  }, props)

  return props
end

function Split:mount()
  if self.mounted then return self end

  self.buffer = Buffer():create(self.config.listed, self.config.scratch)
  self.buffer:assign_options(self.config.buf_options)

  local cmd = ({
    bottom = 'botright split',
    top = 'topleft split',
    left = 'topleft vsplit',
    right = 'botright vsplit',
  })[self.config.position] or 'botright split'

  vim.cmd(cmd)

  self.window = Window(0)
  self.window:assign_options(self.config.win_options)
  self.window:set_height(dimensions.convert(self.config.height))
  self.window:set_width(dimensions.convert(self.config.width))
  vim.api.nvim_win_set_buf(self.window.win_id, self.buffer.bufnr)

  self.mounted = true

  if not self.config.focus then self.window:focus() end

  return self
end

function Split:unmount()
  if self.window and self.window:is_valid() then self.window:close() end

  if self.buffer and self.buffer:is_valid() then self.buffer:delete({ force = true }) end

  self.mounted = false

  return self
end

return Split
