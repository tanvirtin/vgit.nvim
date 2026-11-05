local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')

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
function Component:on_props(prev_props) end
function Component:on_unmount() end

function Component:set_props(updates, callback)
  if not updates then return end

  local prev_props = utils.object.clone(self.props)
  self.props = utils.object.extend(self.props, updates)

  clean_nil_values(self.props)

  if self._mounted then self:on_props(prev_props) end

  if callback then callback() end
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

function Component:with_element() end

return Component
