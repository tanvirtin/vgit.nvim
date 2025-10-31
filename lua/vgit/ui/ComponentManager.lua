local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local LayoutContext = require('vgit.ui.layout.LayoutContext')
local ComponentGroup = require('vgit.ui.ComponentGroup')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local LayoutRenderer = require('vgit.ui.layout.LayoutRenderer')

local ComponentManager = Object:extend()

function ComponentManager:constructor(config)
  config = config or {}

  return {
    context = nil,
    root_component = nil,
    layout_renderer = nil,
    is_destroying = false,
    component_group = ComponentGroup(),
  }
end

function ComponentManager:parse_layout_spec(layout_spec)
  if layout_spec and layout_spec.type then
    if layout_spec.children then
      for i, child in ipairs(layout_spec.children) do
        if child.view and type(child.view.get_layout_spec) == 'function' then
          if not child.view.mounted and type(child.view.mount) == 'function' then
            self.component_group:mount(child.view, self)
          end
          local child_layout_spec = child.view:get_layout_spec()
          layout_spec.children[i] = self:parse_layout_spec(child_layout_spec)
        end
      end
    elseif layout_spec.child then
      if layout_spec.child.view and type(layout_spec.child.view.get_layout_spec) == 'function' then
        if not layout_spec.child.view.mounted and type(layout_spec.child.view.mount) == 'function' then
          self.component_group:mount(layout_spec.child.view, self)
        end
        local child_layout_spec = layout_spec.child.view:get_layout_spec()
        layout_spec.child = self:parse_layout_spec(child_layout_spec)
      end
    end
    return layout_spec
  end

  if layout_spec and layout_spec.plot and layout_spec.plot.win_plot then
    return LayoutSpec.container(LayoutSpec.view(layout_spec, { id = 'element', flex = 1 }))
  end

  if layout_spec and layout_spec.layout then return self:parse_layout_spec(layout_spec.layout) end

  if layout_spec and type(layout_spec) == 'table' then
    return LayoutSpec.container(LayoutSpec.view(layout_spec, { id = 'pane', flex = 1 }))
  end

  error('Unable to convert UI description to LayoutSpec')
end

function ComponentManager:render(layout_config)
  if not layout_config then error('ComponentManager:render() requires layout_config') end

  self.root_component = layout_config.component
  if not self.root_component then error('ComponentManager:render() requires layout_config.component') end

  local default_width = layout_config.mode == 'lens' and '100vw' or '80vw'
  local default_height = layout_config.mode == 'lens' and '35vh' or '60vh'

  self.context = LayoutContext({
    zindex = layout_config.zindex or 2,
    mode = layout_config.mode or 'popup',
    width = layout_config.width or default_width,
    height = layout_config.height or default_height,
    relative = layout_config.relative or 'editor',
    position = layout_config.position or 'center',
  })

  self.root_component.props = self.root_component.props or {}
  self.root_component.props.layout_config = layout_config

  self.component_group:mount(self.root_component, self)

  local layout_spec = self.root_component:get_layout_spec()
  layout_spec = self:parse_layout_spec(layout_spec)

  self.layout_renderer = LayoutRenderer(self.context)
  self.layout_renderer:render(layout_spec)

  self.component_group:call_did_mount()

  self:on('BufWinLeave', function()
    event.await()
    self:destroy()
  end)

  self:on('QuitPre', function()
    event.await()
    self:destroy()
  end)
end

function ComponentManager:destroy()
  if self.is_destroying then return end
  self.is_destroying = true

  self.component_group:unmount()
  self.context:restore_window_options()
end

function ComponentManager:on(event_name, callback)
  self.component_group:on(event_name, callback)
end

function ComponentManager:set_keymap(configs)
  self.component_group:set_keymap(configs)
end

return ComponentManager
