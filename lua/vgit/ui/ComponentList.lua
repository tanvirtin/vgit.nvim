local Object = require('vgit.core.Object')

local ComponentTree = Object:extend()

function ComponentTree:constructor()
  return {
    mounted_components = {},
  }
end

function ComponentTree:mount(component, renderer)
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

function ComponentTree:call_did_mount()
  for _, component in ipairs(self.mounted_components) do
    if component.component_did_mount then component:component_did_mount() end
  end
end

function ComponentTree:unmount()
  for _, component in ipairs(self.mounted_components) do
    component:unmount()
  end
  self.mounted_components = {}
end

function ComponentTree:get_mounted_components()
  return self.mounted_components
end

function ComponentTree:is_mounted(component)
  for _, mounted_component in ipairs(self.mounted_components) do
    if mounted_component == component then return true end
  end
  return false
end

function ComponentTree:on(event_name, callback)
  for _, component in ipairs(self.mounted_components) do
    component:on(event_name, callback)
  end
end

function ComponentTree:set_keymap(configs)
  for _, component in ipairs(self.mounted_components) do
    for _, config in ipairs(configs) do
      component:set_keymap(config, config.handler)
    end
  end
end

return ComponentTree
