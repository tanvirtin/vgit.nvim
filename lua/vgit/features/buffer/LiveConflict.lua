local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local git_buffer_store = require('vgit.git.git_buffer_store')

local LiveConflict = Object:extend()

function LiveConflict:constructor()
  return { name = 'Conflict' }
end

function LiveConflict:register_events()
  git_buffer_store.on(
    { 'attach', 'reload', 'change', 'sync' },
    loop.debounce_coroutine(function(buffer)
      buffer:conflicts()
      buffer:render_conflicts()
    end, 100)
  )

  return self
end

return LiveConflict
