local Object = require('vgit.core.Object')
local event = require('vgit.core.event')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_blame_setting = require('vgit.settings.live_blame')

local LiveBlame = Object:extend()

function LiveBlame:constructor()
  return {
    name = 'Live Blame',
    debounce_cleanups = {},
  }
end

function LiveBlame:reset()
  git_buffer_store.for_each(function(git_buffer)
    git_buffer:clear_blames()
  end)
end

function LiveBlame:cleanup()
  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}
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

    local debounced_blame, cleanup = event.debounce_async(function()
      if not live_blame_setting:get('enabled') then return end

      buffer = buffer or git_buffer_store.current()
      if not buffer then return end

      event.await()
      local conflicts = buffer:get_conflicts()
      if #conflicts ~= 0 then return end

      event.await()
      local _, config_err = buffer:config()
      if config_err then return console.debug.error(config_err) end

      event.await()
      local window = Window(0)
      event.await()
      local lnum = window:get_lnum()

      event.await()
      local _, blame_err = buffer:blame(lnum)
      if blame_err then return console.debug.error(blame_err) end

      event.await()
      buffer:render_blames()
    end, live_blame_setting:get('debounce_ms'))

    table.insert(self.debounce_cleanups, cleanup)
    buffer:on('CursorHold', debounced_blame)
  end)

  return self
end

return LiveBlame
