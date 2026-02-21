local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')
local event = lazy('vgit.core.event')
local Window = lazy('vgit.core.Window')
local console = lazy('vgit.core.console')
local git_buffer_store = lazy('vgit.git.git_buffer_store')
local live_blame_setting = lazy('vgit.settings.live_blame')

local LiveBlame = Object:extend()

function LiveBlame:constructor()
  local debounced_blame, debounced_blame_cleanup = event.debounce_async(function(buffer)
    if not live_blame_setting:get('enabled') then return end

    buffer = buffer or git_buffer_store.current()
    if not buffer then return end

    event.await()
    local conflicts = buffer:get_conflicts()
    if #conflicts ~= 0 then return end

    local _, config_err = buffer:config()
    if config_err then return console.debug.error(config_err) end

    local window = Window(0)
    local lnum = window:get_lnum()

    local _, blame_err = buffer:blame(lnum)
    if blame_err then return console.debug.error(blame_err) end

    buffer:render_blames()
  end, live_blame_setting:get('debounce_ms'))

  return {
    _name = 'Live Blame',
    _debounced_blame = debounced_blame,
    _debounced_blame_cleanup = debounced_blame_cleanup,
  }
end

function LiveBlame:reset()
  git_buffer_store.for_each(function(git_buffer)
    git_buffer:clear_blames()
  end)
end

function LiveBlame:cleanup()
  if self._debounced_blame_cleanup then
    self._debounced_blame_cleanup()
  end
end

function LiveBlame:register_events()
  git_buffer_store.on('attach', function(buffer)
    buffer:on({
      'BufEnter',
      'WinEnter',
      'CursorMoved',
      'InsertEnter',
    }, function()
      buffer:clear_blames()
    end)

    buffer:on('CursorHold', function()
      self._debounced_blame(buffer)
    end)
  end)

  return self
end

return LiveBlame
