local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local buffer_store = require('vgit.core.buffer_store')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_gutter_setting = require('vgit.settings.live_gutter')

local LiveGutter = Object:extend()

function LiveGutter:constructor()
  return { name = 'Live Gutter' }
end

function LiveGutter:fetch(buffer)
  if not live_gutter_setting:get('enabled') then return end

  loop.free_textlock()
  if not buffer:is_valid() then return end

  loop.free_textlock()
  local _, err = buffer:diff()
  if err then
    console.debug.error(err)
    return
  end

  loop.free_textlock()
  buffer:generate_status()
end

LiveGutter.fetch_debounced = loop.debounce_coroutine(function(self, buffer)
  self:fetch(buffer)
end, 10)

function LiveGutter:reset()
  local buffers = buffer_store.list()
  utils.list.for_each(buffers, function(buffer)
    buffer:clear_signs()
  end)
end

function LiveGutter:register_events()
  git_buffer_store.on({ 'attach', 'reload' }, function(buffer)
      self:fetch(buffer)
      buffer:render_signs()
    end)
    .on({ 'change' }, function(buffer)
      self:fetch_debounced(buffer)
    end)
    .on('sync', function(buffer)
      self:fetch_debounced(buffer)
    end)
    .on('detach', function(buffer)
      buffer:clear_extmarks()
    end)
end

return LiveGutter
