local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_blame_setting = require('vgit.settings.live_blame')

local LiveBlame = Object:extend()

function LiveBlame:constructor()
  return {
    name = 'Live Blame',
  }
end

function LiveBlame:reset()
  git_buffer_store.for_each(function(git_buffer)
    git_buffer:clear_blames()
  end)
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
    buffer:on(
      'CursorHold',
      loop.debounce_coroutine(function()
        if not live_blame_setting:get('enabled') then return end

        buffer = buffer or git_buffer_store.current()
        if not buffer then return end

        loop.free_textlock()
        local conflicts = buffer:get_conflicts()
        if #conflicts ~= 0 then return end

        loop.free_textlock()
        local _, config_err = buffer:config()
        if config_err then return console.debug.error(config_err) end

        loop.free_textlock()
        local window = Window(0)
        loop.free_textlock()
        local lnum = window:get_lnum()

        loop.free_textlock()
        local _, blame_err = buffer:blame(lnum)
        if blame_err then return console.debug.error(blame_err) end

        loop.free_textlock()
        buffer:render_blames()
      end, 200)
    )
  end)

  return self
end

return LiveBlame
