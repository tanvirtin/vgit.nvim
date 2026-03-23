local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local ViewportComponent = Component:extend()

function ViewportComponent:constructor(props)
  local instance = Component.constructor(self, props)
  instance._viewport_dirty = true
  instance._last_top = nil
  instance._last_bot = nil
  instance._renderer_attached = false
  return instance
end

function ViewportComponent:mark_viewport_dirty()
  self._viewport_dirty = true
end

function ViewportComponent:is_viewport_unchanged(top, bot)
  return not self._viewport_dirty and self._last_top == top and self._last_bot == bot
end

function ViewportComponent:commit_viewport(top, bot)
  self._viewport_dirty = false
  self._last_top = top
  self._last_bot = bot
end

function ViewportComponent:ensure_renderer_attached(attach_fn)
  if self._renderer_attached then return end
  attach_fn()
  self._renderer_attached = true
end

return ViewportComponent
