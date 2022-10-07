local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local git_service = require('vgit.services.git')
local Namespace = require('vgit.core.Namespace')
local event_type = require('vgit.core.event_type')
local live_blame_setting = require('vgit.settings.live_blame')

local LiveBlame = Object:extend()

function LiveBlame:constructor()
  return {
    name = 'Live Blame',
    id = 1,
    last_lnum = nil,
    namespace = Namespace(),
  }
end

function LiveBlame:register_events()
  event
    .on(event_type.BufEnter, function() self:desync_all() end)
    .on(event_type.WinEnter, function() self:desync_all() end)
    .on(event_type.CursorHold, function() self:sync() end)
    .on(event_type.CursorMoved, function() self:desync() end)
    .on(event_type.InsertEnter, function() self:desync() end)

  return self
end

function LiveBlame:display(lnum, buffer, config, blame)
  if buffer:is_valid() then
    local virt_text = live_blame_setting:get('format')(blame, config)

    if type(virt_text) == 'string' then
      loop.await()
      self.namespace:transpose_virtual_text(buffer, virt_text, 'GitComment', lnum - 1, 0, 'eol')
    end
  end
end

function LiveBlame:clear(buffer)
  if buffer:is_valid() then
    self.namespace:clear(buffer)
  end
end

LiveBlame.sync = loop.debounced_async(function(self)
  if not live_blame_setting:get('enabled') then
    return
  end

  loop.await()
  local window = Window(0)
  loop.await()
  local buffer = git_service.store.current()

  if not buffer then
    return
  end
  loop.await()

  if buffer:editing() then
    console.debug.warning(string.format('Buffer %s is being edited right now', buffer.bufnr))
    return
  end

  if not buffer:is_valid() then
    return
  end

  if not buffer.git_blob:is_tracked() then
    return
  end

  loop.await()
  local lnum = window:get_lnum()

  if self.last_lnum and self.last_lnum == lnum then
    return
  end

  loop.await()
  local blame_err, blame = buffer.git_blob:blame_line(lnum)

  loop.await()
  if not buffer:is_valid() then
    return self
  end

  loop.await()
  local new_lnum = window:get_lnum()

  if lnum ~= new_lnum then
    return
  end

  if blame_err then
    console.debug.error(blame_err)
    return
  end

  loop.await()
  local config_err, config = buffer.git_blob:get_config()

  if config_err then
    console.debug.error(config_err)
    return
  end

  if not buffer then
    return
  end

  loop.await()
  self:clear(buffer)
  self:display(lnum, buffer, config, blame)
  self.last_lnum = lnum
end, 20)

function LiveBlame:desync(force)
  loop.await()
  local window = Window(0)
  local buffer = git_service.store.current()

  if not buffer then
    return
  end

  loop.await()
  buffer = git_service.store.get(buffer)
  loop.await()

  local lnum = window:get_lnum()

  if not force and self.last_lnum and self.last_lnum == lnum then
    return
  end

  if not buffer then
    return
  end

  self:clear(buffer)
end

function LiveBlame:desync_all(force)
  if not live_blame_setting:get('enabled') and not force then
    return
  end

  local buffers = Buffer:list()

  for i = 1, #buffers do
    local buffer = buffers[i]

    if buffer then
      self:clear(buffer)
    end
  end
end

function LiveBlame:resync()
  self:desync_all(true)
  self:sync()
end

return LiveBlame
