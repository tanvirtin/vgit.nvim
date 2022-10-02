local Object = require('vgit.core.Object')

local Scene = Object:extend()

function Scene:constructor()
  return {
    components = {},
    state = {
      default_global_opts = {},
    },
  }
end

function Scene:set(key, component)
  self.components[key] = component

  return self
end

function Scene:get(key)
  return self.components[key]
end

function Scene:destroy()
  for _, component in pairs(self.components) do
    component:unmount()
  end

  return self
end

return Scene
