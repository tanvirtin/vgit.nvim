local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')

local Component = Object:extend()

function Component:constructor(props)
  return {
    props = props or {},
    state = self:get_initial_state() or {},
    mounted = false,
    _needs_update = false,
  }
end

function Component:get_initial_state()
  return {}
end

function Component:component_will_mount() end

function Component:component_did_mount() end

function Component:component_will_update(next_state) end

function Component:component_did_update(prev_state) end

function Component:should_component_update(next_props, next_state)
  return true
end

function Component:component_will_unmount() end

function Component:set_props(updates, callback)
  if not updates then return end

  local next_props = vim.tbl_extend('force', self.props, updates)

  if not self:should_component_update(next_props, self.state) then return end

  local prev_state = self.state

  self.props = next_props
  self._needs_update = true

  if self.mounted and self._needs_update then
    self:update(prev_state)
    self._needs_update = false
  end

  if callback then callback() end
end

function Component:set_state(updates, callback)
  if not updates then return end

  local next_state = vim.tbl_extend('force', self.state, updates)

  if not self:should_component_update(self.props, next_state) then return end

  local prev_state = self.state

  self.state = next_state
  self._needs_update = true

  if self.mounted and self._needs_update then
    self:update(prev_state)
    self._needs_update = false
  end

  if callback then callback() end
end

function Component:update(prev_state)
  if not self.mounted or not self._needs_update then return end

  self:component_will_update(self.state)

  self:render()

  self._needs_update = false
  self:component_did_update(prev_state)
end

function Component:render()
  error('Component:render() must be implemented by subclass')
end

function Component:mount()
  if self.mounted then return end

  self:component_will_mount()

  self.mounted = true
end

function Component:unmount()
  if not self.mounted then return end

  self:component_will_unmount()

  self.mounted = false
  self._needs_update = false
end

function Component:is_mounted()
  return self.mounted
end

function Component:on(event_name, callback)
  if not self._element then return end
  self._element:on(event_name, callback)
end

function Component:set_keymap(mode_or_opts, key_or_callback, handler, desc)
  if not self._element then return end
  self._element:set_keymap(mode_or_opts, key_or_callback, handler, desc)
end

return Component
