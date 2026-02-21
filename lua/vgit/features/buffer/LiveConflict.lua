local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')
local event = lazy('vgit.core.event')
local git_buffer_store = lazy('vgit.git.git_buffer_store')

local LiveConflict = Object:extend()

function LiveConflict:constructor()
  local debounced_conflicts, debounced_conflicts_cleanup = event.debounce_async(function(buffer)
    buffer:conflicts()
    buffer:render_conflicts()
  end, 100)

  return {
    _name = 'Conflict',
    _debounced_conflicts = debounced_conflicts,
    _debounced_conflicts_cleanup = debounced_conflicts_cleanup,
  }
end

function LiveConflict:register_events()
  git_buffer_store.on(
    { 'attach', 'reload', 'change', 'sync' },
    self._debounced_conflicts
  )

  return self
end

function LiveConflict:cleanup()
  if self._debounced_conflicts_cleanup then
    self._debounced_conflicts_cleanup()
  end
end

return LiveConflict
