local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local CommitComponent = lazy('vgit.ui.components.CommitComponent')

local CommitView = View:extend()

function CommitView:constructor()
  local instance = View.constructor(self)
  instance._component = nil
  return instance
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

function CommitView:start_insert()
  if self._component then self._component:start_insert() end
  return self
end

function CommitView:is_valid()
  if self._component then return self._component:is_valid() end
  return false
end

return CommitView
