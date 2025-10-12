local Component = require('vgit.ui.Component')
local Element = require('vgit.ui.elements.Element')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

local BorderComponent = Component:extend()

function BorderComponent:constructor(props)
  return Component.constructor(self, props)
end

function BorderComponent:render()
  local winhl = self.props.winhl or 'Normal:VGitBorder'

  local element = Element({
    buf_options = {
      modifiable = false,
      buflisted = false,
      bufhidden = 'wipe',
    },
    win_options = {
      winhl = winhl,
      cursorline = false,
      cursorcolumn = false,
    },
    win_plot = {
      focusable = false,
    },
  })

  self._element = element

  return LayoutSpec.view(element, { height = 1 })
end

function BorderComponent:unmount()
  if not self.mounted then return end

  self._element:unmount()
  self._element = nil

  Component.unmount(self)
end

return BorderComponent
