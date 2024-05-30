local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local git_buffer_store = require('vgit.git.git_buffer_store')

local LiveConflict = Object:extend()

function LiveConflict:constructor()
  return { name = 'Conflict' }
end

function LiveConflict:render(buffer)
  local has_conflict = buffer:has_conflict()
  if not has_conflict then return end

  loop.free_textlock()
  buffer:parse_conflicts()
  buffer:render_conflicts()
end

function LiveConflict:register_events()
  git_buffer_store
    .attach('attach', function(buffer)
      self:render(buffer)
    end)
    .attach('reload', function(buffer)
      self:render(buffer)
    end)
    .attach('change', function(buffer)
      self:render(buffer)
    end)
    .attach('watch', function(buffer)
      self:render(buffer)
    end)
    .attach('git_watch', function(buffers)
      for i = 1, #buffers do
        self:render(buffers[i])
      end
    end)

  return self
end

return LiveConflict
