local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local console = lazy('vgit.core.console')
local git_buffer_store = lazy('vgit.git.git_buffer_store')
local live_gutter_setting = lazy('vgit.settings.live_gutter')

local LiveGutter = Object:extend()

function LiveGutter:constructor()
  local fetch_debounced_fn, fetch_debounced_cleanup = event.debounce_async(function(self_ref, buffer)
    self_ref:fetch(buffer)
  end, live_gutter_setting:get('debounce_ms'))

  return {
    _name = 'Live Gutter',
    _fetch_debounced = fetch_debounced_fn,
    _fetch_debounced_cleanup = fetch_debounced_cleanup,
  }
end

function LiveGutter:is_enabled()
  return live_gutter_setting:get('enabled') == true
end

function LiveGutter:cleanup()
  if self._fetch_debounced_cleanup then self._fetch_debounced_cleanup() end
end

function LiveGutter:fetch(buffer)
  event.await()
  if not buffer:is_valid() then return end
  if not buffer:acquire() then return end

  local _, err = buffer:diff()
  buffer:release()

  if err then
    console.debug.error(err)
    return
  end

  buffer:generate_status()
end

function LiveGutter:fetch_debounced(buffer)
  self._fetch_debounced(self, buffer)
end

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

  return self
end

return LiveGutter
