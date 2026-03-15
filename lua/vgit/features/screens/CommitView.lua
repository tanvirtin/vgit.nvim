local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local CommitComponent = lazy('vgit.ui.components.CommitComponent')

local CommitView = Object:extend()

function CommitView:constructor()
  return {
    _component = nil,
    _component_manager = nil,
    _destroyed = false,
  }
end

function CommitView:create(opts)
  opts = opts or {}

  self._component = CommitComponent({
    filetype = opts.filetype or 'gitcommit',
    confirm_key = opts.confirm_key,
    cancel_key = opts.cancel_key,
    on_confirm = opts.on_confirm,
    on_cancel = opts.on_cancel,
  })

  self._component_manager = ComponentManager()
  self._component_manager:render({
    component = self._component,
    mode = 'split',
    split_height = opts.height or 20,
    split_direction = opts.split_direction or 'botright',
  })

  return self
end

function CommitView:set_lines(lines)
  if self._component then self._component:set_lines(lines) end
  return self
end

function CommitView:get_lines()
  if self._component then return self._component:get_lines() end
  return {}
end

function CommitView:set_cursor(cursor)
  if self._component then self._component:set_cursor(cursor) end
  return self
end

function CommitView:focus()
  if self._component then self._component:focus() end
  return self
end

function CommitView:is_valid()
  if self._component then return self._component:is_valid() end
  return false
end

function CommitView:destroy()
  if self._destroyed then return end
  self._destroyed = true

  if self._component_manager then
    self._component_manager:destroy()
    self._component_manager = nil
  end
  self._component = nil
end

return CommitView
