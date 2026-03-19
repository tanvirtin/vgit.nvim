local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

local View = Object:extend()

function View:constructor()
  return {
    _component_manager = nil,
    _destroyed = false,
    _debounce_cleanups = {},
  }
end

function View:create()
  error('View:create() must be implemented by subclass')
end

function View:destroy()
  if self._destroyed then return end
  self._destroyed = true

  for _, cleanup in ipairs(self._debounce_cleanups) do
    cleanup()
  end
  self._debounce_cleanups = {}

  if self._component_manager then
    self._component_manager:destroy()
    self._component_manager = nil
  end
end

function View:is_destroyed()
  return self._destroyed
end

function View:on_git_change() end

return View
