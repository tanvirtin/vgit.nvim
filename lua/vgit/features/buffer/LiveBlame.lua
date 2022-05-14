local Namespace = require('vgit.core.Namespace')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local GitBuffer = require('vgit.git.GitBuffer')
local console = require('vgit.core.console')
local live_blame_setting = require('vgit.settings.live_blame')
local git_buffer_store = require('vgit.git.git_buffer_store')
local Feature = require('vgit.Feature')
local loop = require('vgit.core.loop')

local LiveBlame = Feature:extend()

function LiveBlame:constructor()
  return {
    name = 'Live Blame',
    id = 1,
    last_lnum = nil,
    namespace = Namespace(),
  }
end

function LiveBlame:display(lnum, buffer, config, blame)
  if buffer:is_valid() then
    local virt_text = live_blame_setting:get('format')(blame, config)

    if type(virt_text) == 'string' then
      loop.await_fast_event()
      self.namespace:transpose_virtual_text(
        buffer,
        virt_text,
        'GitComment',
        lnum - 1,
        0,
        'eol'
      )
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

  loop.await_fast_event()
  local window = Window(0)
  loop.await_fast_event()
  local buffer = git_buffer_store.current()
  local git_buffer = GitBuffer(buffer)

  if not buffer then
    return
  end
  loop.await_fast_event()

  if buffer:editing() then
    console.debug.warning(
      string.format('Buffer %s is being edited right now', buffer.bufnr)
    )
    return
  end

  if not buffer:is_valid() then
    return
  end

  if not git_buffer:is_tracked() then
    return
  end

  loop.await_fast_event()
  local lnum = window:get_lnum()

  if self.last_lnum and self.last_lnum == lnum then
    return
  end

  loop.await_fast_event()
  local blame_err, blame = buffer.git_object:blame_line(lnum)

  loop.await_fast_event()
  if not buffer:is_valid() then
    return self
  end

  loop.await_fast_event()
  local new_lnum = window:get_lnum()

  if lnum ~= new_lnum then
    return
  end

  if blame_err then
    console.debug.error(blame_err)
    return
  end

  loop.await_fast_event()
  local config_err, config = buffer.git_object:config()

  if config_err then
    console.debug.error(config_err)
    return
  end

  if not buffer then
    return
  end

  loop.await_fast_event()
  self:clear(buffer)
  self:display(lnum, buffer, config, blame)
  self.last_lnum = lnum
end, 20)

function LiveBlame:desync(force)
  loop.await_fast_event()
  local window = Window(0)
  local buffer = git_buffer_store.current()

  if not buffer then
    return
  end

  loop.await_fast_event()
  buffer = git_buffer_store.get(buffer)
  loop.await_fast_event()

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
