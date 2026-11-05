local lazy = require('vgit.core.lazy')

local ElementComponent = lazy('vgit.ui.ElementComponent')
local CompositeComponent = lazy('vgit.ui.CompositeComponent')

local function resolve(value, props)
  if type(value) == 'function' then return value(props) end

  return value
end

local function declare_element_component(config)
  local Class = ElementComponent:extend()

  function Class:get_buf_options()
    return resolve(config.buf_options, self.props)
  end

  function Class:get_win_options()
    return resolve(config.win_options, self.props)
  end

  function Class:get_win_plot()
    return config.win_plot
  end

  function Class:get_layout_opts()
    return config.layout_opts or { flex = 1 }
  end

  return Class
end

local function declare_composite_component(config)
  local Class = CompositeComponent:extend()

  function Class:get_child_classes()
    return config.children
  end

  return Class
end

local function declare_component(config)
  config = config or {}

  local Class = config.children ~= nil and declare_composite_component(config) or declare_element_component(config)

  if config.on_mount then
    function Class:on_mount()
      config.on_mount(self)
    end
  end

  if config.on_props then
    function Class:on_props(prev_props)
      config.on_props(self, prev_props)
    end
  end

  if config.on_unmount then
    function Class:on_unmount()
      config.on_unmount(self)
    end
  end

  return Class
end

return declare_component
