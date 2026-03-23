local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local create_component_element = require('vgit.ui.create_component_element')

local Component = Object:extend()

local function clean_nil_values(props)
  for k, v in pairs(props) do
    if v == vim.NIL then props[k] = nil end
  end
end

Component.clean_nil_values = clean_nil_values

function Component:constructor(props)
  return {
    props = props or {},
    state = self:get_initial_state() or {},
    _mounted = false,
  }
end

function Component:get_initial_state()
  return {}
end

function Component:mount()
  if self._mounted then return end
  self._mounted = true
end

function Component:on_mount() end
function Component:render() end

function Component:set_props(updates)
  if updates then self.props = utils.object.extend(self.props, updates) end
  clean_nil_values(self.props)
end

function Component:set_state(updates)
  if not updates then return end
  self.state = utils.object.extend(self.state, updates)
  if self._mounted then self:render() end
end

function Component:unmount()
  self._mounted = false
end

function Component:is_mounted()
  return self._mounted
end

function Component:with_element(fn)
  if self._element and self._element:is_valid() then return fn(self._element) end
end

local function resolve(value, props)
  if type(value) == 'function' then return value(props) end
  return value
end

local function create_element(config, props)
  return create_component_element({
    buf_options = resolve(config.buf_options, props),
    win_options = resolve(config.win_options, props),
    win_plot = config.win_plot,
  }, props)
end

local define_single_element_methods = require('vgit.ui.element_delegation').define_single_element_methods

local function CreateComponent(config)
  local ViewportComponent = lazy('vgit.ui.ViewportComponent')

  config = config or {}

  local has_elements = config.elements ~= nil
  local has_children = config.children ~= nil
  local is_single = not has_elements and not has_children

  local Base = config.viewport and ViewportComponent or Component
  local Class = Base:extend()
  Class.super = Base

  if is_single then
    function Class:constructor(props)
      local instance = Class.super.constructor(self, props)
      instance._element = nil
      return instance
    end
  elseif has_elements then
    function Class:constructor(props)
      local instance = Class.super.constructor(self, props)
      instance.elements = {}
      return instance
    end
  else
    function Class:constructor(props)
      local instance = Class.super.constructor(self, props)
      instance.children = {}
      return instance
    end
  end

  if is_single then
    function Class:mount()
      if self._mounted then return end
      if not self._element then self._element = create_element(config, self.props) end
      self._mounted = true
    end
  elseif has_elements then
    function Class:mount()
      if self._mounted then return end
      for name, el_cfg in pairs(config.elements) do
        if not self.elements[name] then
          self.elements[name] = create_component_element({
            buf_options = el_cfg.buf_options,
            win_options = el_cfg.win_options,
            win_plot = el_cfg.win_plot,
          }, self.props)
        end
      end
      self._mounted = true
    end
  else
    function Class:mount()
      if self._mounted then return end
      for name, ChildClass in pairs(config.children) do
        if not self.children[name] then self.children[name] = ChildClass({}) end
      end
      self._mounted = true
    end
  end

  function Class:on_mount()
    if config.on_mount then config.on_mount(self) end
  end

  function Class:render() end

  function Class:set_props(updates, callback)
    if not updates then return end

    local prev_props = utils.object.clone(self.props)
    self.props = utils.object.extend(self.props, updates)

    clean_nil_values(self.props)

    if self._mounted and config.on_props then config.on_props(self, prev_props) end

    if callback then callback() end
  end

  if is_single then
    function Class:unmount()
      if not self._mounted then return end
      if config.on_unmount then config.on_unmount(self) end
      if self._element then
        self._element:unmount()
        self._element = nil
      end
      self._mounted = false
    end
  elseif has_elements then
    function Class:unmount()
      if not self._mounted then return end
      if config.on_unmount then config.on_unmount(self) end
      for _, el in pairs(self.elements) do
        if el then el:unmount() end
      end
      self.elements = {}
      self._mounted = false
    end
  else
    function Class:unmount()
      if not self._mounted then return end
      if config.on_unmount then config.on_unmount(self) end
      if self.children then
        for _, child in pairs(self.children) do
          if child.unmount then child:unmount() end
        end
      end
      self._mounted = false
    end
  end

  -- get_layout_spec

  if is_single then
    function Class:get_layout_spec()
      return LayoutSpec.view(self._element, config.layout_opts or { flex = 1 })
    end
  else
    function Class:get_layout_spec()
      return self:layout(LayoutSpec)
    end
  end

  if is_single then define_single_element_methods(Class) end

  return Class
end

-- Component({config}) invokes the factory.
-- Give Component its own metatable so __call doesn't poison Object's lazy proxy.
local object_proxy = getmetatable(Component)
local component_mt = {}
for k, v in pairs(object_proxy) do
  component_mt[k] = v
end
component_mt.__call = function(_, config)
  return CreateComponent(config)
end
setmetatable(component_mt, { __index = object_proxy })
setmetatable(Component, component_mt)

return Component
