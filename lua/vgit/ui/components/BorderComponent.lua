local Component = require('vgit.ui.Component')
local Element = require('vgit.ui.elements.Element')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

local BorderComponent = Component:extend()

function BorderComponent:constructor(props)
  return Component.constructor(self, props)
end

function BorderComponent:component_will_mount()
  local winhl = self.props.winhl or 'Normal:VGitBorder'

  self._element = Element({
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
end

function BorderComponent:render() end

function BorderComponent:component_did_mount() self:render() end

function BorderComponent:get_layout_spec()
  return LayoutSpec.view(self._element, { height = 1 })
end

function BorderComponent:unmount()
  if not self.mounted then return end

  self._element:unmount()
  self._element = nil

  Component.unmount(self)
end

return BorderComponent
