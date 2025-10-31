local Object = require('vgit.core.Object')
local event = require('vgit.core.event')
local git_buffer_store = require('vgit.git.git_buffer_store')

local LiveConflict = Object:extend()

function LiveConflict:constructor()
  return {
    name = 'Conflict',
    debounce_cleanups = {},
  }
end

function LiveConflict:register_events()
  local debounced_conflicts, cleanup = event.debounce_async(function(buffer)
    buffer:conflicts()
    buffer:render_conflicts()
  end, 100)

  table.insert(self.debounce_cleanups, cleanup)

  git_buffer_store.on(
    { 'attach', 'reload', 'change', 'sync' },
    debounced_conflicts
  )

  return self
end

function LiveConflict:cleanup()
  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}
end

return LiveConflict
