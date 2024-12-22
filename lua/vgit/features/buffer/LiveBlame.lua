local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local Namespace = require('vgit.core.Namespace')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_blame_setting = require('vgit.settings.live_blame')

local LiveBlame = Object:extend()

function LiveBlame:constructor()
  return {
    id = 1,
    name = 'Live Blame',
    namespace = Namespace(),
    last_lnum = nil,
  }
end

function LiveBlame:display(lnum, buffer, config, blame)
  if buffer:is_valid() then
    local text = live_blame_setting:get('format')(blame, config)

    if type(text) == 'string' then
      loop.free_textlock()
      self.namespace:transpose_virtual_text(buffer, {
        text = text,
        hl = 'GitComment',
        row = lnum - 1,
        col = 0,
        pos = 'eol',
      })
    end
  end
end

function LiveBlame:clear(buffer)
  if buffer:is_valid() then self.namespace:clear(buffer) end
end

function LiveBlame:reset()
  git_buffer_store.for_each(function(git_buffer)
    self:clear(git_buffer)
  end)
end

function LiveBlame:render(git_buffer)
  if not live_blame_setting:get('enabled') then return end

  git_buffer = git_buffer or git_buffer_store.current()

  if not git_buffer then return end

  loop.free_textlock()
  local config, config_err = git_buffer:config()
  if config_err then return console.debug.error(config_err) end

  loop.free_textlock()
  local window = Window(0)
  loop.free_textlock()
  local lnum = window:get_lnum()

  if self.last_lnum == lnum then return end

  loop.free_textlock()
  local blame, blame_err = git_buffer:blame(lnum)

  loop.free_textlock()
  local new_lnum = window:get_lnum()

  if lnum ~= new_lnum then return end

  if blame_err then
    console.debug.error(blame_err)
    return
  end

  loop.free_textlock()

  self:clear(git_buffer)
  self:display(lnum, git_buffer, config, blame)
  self.last_lnum = lnum
end

function LiveBlame:register_events()
  git_buffer_store.on('attach', function(buffer)
    buffer:on({
      event.type.BufEnter,
      event.type.WinEnter,
      event.type.CursorMoved,
      event.type.InsertEnter,
    }, function()
      self:reset()
    end)
    buffer:on(event.type.CursorHold, function()
      self:render()
    end)
  end)

  return self
end

return LiveBlame
