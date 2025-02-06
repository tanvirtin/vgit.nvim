local Object = require('vgit.core.Object')
local git_buffer_store = require('vgit.git.git_buffer_store')

local LiveConflict = Object:extend()

function LiveConflict:constructor()
  return { name = 'Conflict' }
end

function LiveConflict:register_events()
  git_buffer_store.on({ 'attach', 'reload', 'change', 'sync' }, function(buffer)
    buffer:conflicts()
    buffer:render_conflicts()
  end)

  return self
end

return LiveConflict
