local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local dimensions = require('vgit.ui.dimensions')
local scene_setting = require('vgit.settings.scene')

local Popup = Component:extend()

function Popup:constructor(props)
  return utils.object.assign({
    config = {
      elements = {},
      height = '100vh',
      width = '100vw',
      position = 'center',
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
        cursorbind = false,
        cursorline = true,
        statusline = ' ',
      },
      win_plot = {
        style = 'minimal',
        relative = 'editor',
        focusable = true,
        focus = true,
        zindex = 100,
      },
      border = {
        enabled = false,
        title = nil,
        style = 'single',
        highlight = 'FloatBorder',
      },
      locked = false,
    },
  }, props)
end

function Popup:calculate_position()
  local position = self.config.position or 'center'
  local content_height = math.floor(dimensions.convert(self.config.height))
  local content_width = math.floor(dimensions.convert(self.config.width))
  local screen_lines = vim.o.lines
  local screen_columns = vim.o.columns

  local total_height, total_width
  if self.config.border.enabled then
    total_height = content_height + 2
    total_width = content_width + 2
  else
    total_height = content_height
    total_width = content_width
  end

  local position_handlers = {
    top_left = function()
      return 0, 0
    end,
    top_center = function(_, width)
      return 0, math.max(0, math.floor((screen_columns - width) / 2))
    end,
    top_right = function(_, width)
      return 0, math.max(0, screen_columns - width)
    end,
    bottom_left = function(height, _)
      return math.max(0, screen_lines - height), 0
    end,
    bottom_center = function(height, width)
      return math.max(0, screen_lines - height), math.max(0, math.floor((screen_columns - width) / 2))
    end,
    bottom_right = function(height, width)
      return math.max(0, screen_lines - height), math.max(0, screen_columns - width)
    end,
    center = function(height, width)
      return math.max(0, math.floor((screen_lines - height) / 2)), math.max(0, math.floor((screen_columns - width) / 2))
    end
  }

  local handler = position_handlers[position]
  if not handler then error('invalid position provided') end

  local row, col = handler(total_height, total_width)

  return row, col, content_height, content_width
end

function Popup:mount()
  if self.mounted then return self end

  local total_row, total_col, content_height, content_width = self:calculate_position()

  self.buffer = Buffer():create(self.config.buf_options.buflisted, true)
  self.buffer:assign_options(self.config.buf_options)

  local content_win_plot = utils.object.assign({
    relative = 'editor',
    row = total_row,
    col = total_col,
    width = content_width,
    height = content_height,
  }, self.config.win_plot)

  if self.config.border.enabled then
    content_win_plot.border = self.config.border.style
    content_win_plot.title = self.config.border.title
    content_win_plot.title_pos = 'center'

    if self.config.border.highlight then
      self.config.win_options.winhl = table.concat({
        self.config.win_options.winhl,
        'FloatBorder:' .. self.config.border.highlight,
        'FloatTitle:' .. self.config.border.highlight
      }, ',')
    end
  end

  self.window = Window:open(self.buffer, content_win_plot)
  self.window:assign_options(self.config.win_options)

  self.mounted = true

  if self.config.filetype then self:set_filetype(self.config.filetype) end

  self
      :on('BufWinLeave', function()
        loop.free_textlock()
        self:unmount()
      end)
      :on('QuitPre', function()
        self:unmount()
      end)

    self:set_keymap({
      mode = 'n',
      desc = 'Quit',
      mapping = scene_setting:get('keymaps').quit,
    }, function() self:unmount() end)

  return self
end

function Popup:unmount()
  if self.window and self.window:is_valid() then self.window:close() end
  if self.buffer and self.buffer:is_valid() then self.buffer:delete({ force = true }) end

  self.mounted = false

  return self
end

return Popup
