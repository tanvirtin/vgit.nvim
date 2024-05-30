local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local GitBuffer = require('vgit.git.GitBuffer')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_gutter_setting = require('vgit.settings.live_gutter')

local LiveGutter = Object:extend()

function LiveGutter:constructor()
  return { name = 'Live Gutter' }
end

LiveGutter.fetch = loop.debounce_coroutine(function(self, buffer)
  loop.free_textlock()
  if not buffer:is_valid() then return self end

  loop.free_textlock()
  local _, err = buffer:live_hunks()

  loop.free_textlock()
  if err then
    console.debug.error(err)
    return self
  end

  buffer:sign_unplace()
  buffer:generate_status()

  return self
end, 10)

function LiveGutter:render(buffer, top, bot)
  if not live_gutter_setting:get('enabled') then return self end

  local hunks = buffer.git_object.hunks
  if not hunks then return self end

  local signs = {}
  for i = top, bot do
    signs[#signs + 1] = buffer.signs[i]
  end

  buffer:sign_placelist(signs)

  return self
end

function LiveGutter:reset()
  local buffers = GitBuffer:list()

  for i = 1, #buffers do
    local buffer = buffers[i]

    if buffer then
      buffer:sign_unplace()
    end
  end

  return self
end

function LiveGutter:register_events()
  git_buffer_store
    .attach('attach', function(buffer)
      self:fetch(buffer)
    end)
    .attach('reload', function(buffer)
      self:fetch(buffer)
    end)
    .attach('change', function(buffer)
      self:fetch(buffer)
    end)
    .attach('watch', function(buffer)
      buffer:sync()
      self:fetch(buffer)
    end)
    .attach('git_watch', function(buffers)
      for i = 1, #buffers do
        local buffer = buffers[i]
        self:fetch(buffer)
      end
    end)
    .attach('render', function(buffer, top, bot)
      self:render(buffer, top, bot + 1)
    end)

  return self
end

return LiveGutter
