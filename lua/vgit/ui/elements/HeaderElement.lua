local utils = require('vgit.core.utils')
local Namespace = require('vgit.core.Namespace')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')

local HeaderElement = Object:extend()

function HeaderElement:new()
  return setmetatable({
    buffer = nil,
    window = nil,
    namespace = nil,
  }, HeaderElement)
end

function HeaderElement:make_border(c)
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

local function get_border(options)
  local type = utils.object.pick({ 'topbottom', 'top', 'bot' }, options.type)
  if type == 'topbottom' then
    return { '─', '─', '─', ' ', '─', '─', '─', ' ' }
  end
  if type == 'top' then
    return { '─', '─', '─', ' ', ' ', ' ', ' ', ' ' }
  end
  if type == 'bot' then
    return { ' ', ' ', ' ', ' ', '─', '─', '─', ' ' }
  end
  return { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }
end

function HeaderElement:mount(options)
  self.buffer = Buffer:new():create()
  local buffer = self.buffer
  buffer:assign_options({
    modifiable = false,
    buflisted = false,
    bufhidden = 'wipe',
  })
  self.window = Window
    :open(buffer, {
      border = self:make_border({
        chars = get_border(options),
        hl = 'GitBorder',
      }),
      style = 'minimal',
      focusable = false,
      relative = 'editor',
      row = options.row,
      col = options.col,
      width = options.width - 2,
      height = 1,
      zindex = 100,
    })
    :assign_options({
      cursorbind = false,
      scrollbind = false,
      winhl = 'Normal:GitBackgroundSecondary',
    })
  self.namespace = Namespace:new()
  return self
end

function HeaderElement:get_height()
  return 3
end

function HeaderElement:unmount()
  self.window:close()
  return self
end

function HeaderElement:set_lines(lines)
  self.buffer:set_lines(lines)
  return self
end

function HeaderElement:add_highlight(hl, row, col_start, col_end)
  self.buffer:add_highlight(hl, row, col_start, col_end)
  return self
end

function HeaderElement:transpose_virtual_text(text, hl, row, col, pos)
  self.buffer:transpose_virtual_text(text, hl, row, col, pos)
  return self
end

function HeaderElement:clear_namespace()
  self.buffer:clear_namespace()
  return self
end

function HeaderElement:notify(text)
  self.namespace:transpose_virtual_text(
    self.buffer,
    text,
    'GitComment',
    0,
    0,
    'eol'
  )
  return self
end

function HeaderElement:clear_notification()
  self.namespace:clear(self.buffer)
  return self
end

function HeaderElement:clear()
  self:set_lines({})
  self:clear_namespace()
  return self
end

return HeaderElement
