local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')

local ComponentGroup = Object:extend()

function ComponentGroup:constructor()
  return {
    mounted_components = {},
  }
end

function ComponentGroup:mount(component, renderer)
  if component.mounted then return end

  if renderer.context then
    component.props = component.props or {}
    local context_props = renderer.context:get_props_for_component()
    for k, v in pairs(context_props) do
      if component.props[k] == nil then component.props[k] = v end
    end
  end

  component:mount()
  table.insert(self.mounted_components, component)
end

function ComponentGroup:call_did_mount()
  for _, component in ipairs(self.mounted_components) do
    if component.component_did_mount then component:component_did_mount() end
  end
end

function ComponentGroup:unmount()
  for _, component in ipairs(self.mounted_components) do
    component:unmount()
  end
  self.mounted_components = {}
end

function ComponentGroup:get_mounted_components()
  return self.mounted_components
end

function ComponentGroup:is_mounted(component)
  for _, mounted_component in ipairs(self.mounted_components) do
    if mounted_component == component then return true end
  end
  return false
end

function ComponentGroup:on(event_name, callback)
  for _, component in ipairs(self.mounted_components) do
    component:on(event_name, callback)
  end
end

function ComponentGroup:set_keymap(configs)
  for _, component in ipairs(self.mounted_components) do
    for _, config in ipairs(configs) do
      component:set_keymap(config, config.handler)
    end
  end
end

return ComponentGroup
