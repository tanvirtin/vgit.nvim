local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_gutter_setting = require('vgit.settings.live_gutter')

local LiveGutter = Object:extend()

function LiveGutter:constructor()
  return { name = 'Live Gutter' }
end

function LiveGutter:is_enabled()
  return live_gutter_setting:get('enabled') == true
end

function LiveGutter:fetch(buffer)
  loop.free_textlock()
  if not buffer:is_valid() then return end

  loop.free_textlock()
  local _, err = buffer:diff()

  if err then
    loop.free_textlock()
    console.debug.error(err)
    return
  end

  loop.free_textlock()
  buffer:generate_status()
end

LiveGutter.fetch_debounced = loop.debounce_coroutine(function(self, buffer)
  self:fetch(buffer)
end, 200)

function LiveGutter:toggle()
  git_buffer_store.for_each(function(buffer)
    if self:is_enabled() then
      self:fetch(buffer)
    else
      buffer:reset_signs()
    end
    buffer:render_signs()
  end)
end

function LiveGutter:register_events()
  git_buffer_store
    .on({ 'attach', 'reload' }, function(buffer)
      if not self:is_enabled() then return end

      self:fetch(buffer)
      buffer:render_signs()
    end)
    .on({ 'change' }, function(buffer)
      if not self:is_enabled() then return end
      self:fetch_debounced(buffer)
    end)
    .on('sync', function(buffer)
      if not self:is_enabled() then return end
      self:fetch_debounced(buffer)
    end)
    .on('detach', function(buffer)
      buffer:clear_extmarks()
    end)
end

return LiveGutter
