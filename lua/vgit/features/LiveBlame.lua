local Namespace = require('vgit.core.Namespace')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local live_blame_setting = require('vgit.settings.live_blame')
local loop = require('vgit.core.loop')

local Feature = require('vgit.Feature')
local LiveBlame = Feature:extend()

function LiveBlame:new(git_store)
  return setmetatable({
    id = 1,
    git_store = git_store,
    last_lnum = nil,
    namespace = Namespace:new(),
  }, LiveBlame)
end

function LiveBlame:display(lnum, buffer, config, blame)
  loop.await_fast_event()
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

function LiveBlame:hide(buffer)
  loop.await_fast_event()
  if buffer:is_valid() then
    loop.await_fast_event()
    self.namespace:clear(buffer)
  end
end

LiveBlame.sync = loop.brakecheck(loop.async(function(self)
  loop.await_fast_event()
  local window = Window:new(0)
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  loop.await_fast_event()
  if buffer:editing() then
    console.debug(
      string.format('Buffer %s is being edited right now', buffer.bufnr)
    )
    return
  end
  loop.await_fast_event()
  if not self:is_buffer_valid(buffer) then
    return
  end
  loop.await_fast_event()
  if not self:is_buffer_tracked(buffer) then
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
    console.debug(
      'Buffer on which blame was live blame was being synced is no longer valid'
    )
  end
  loop.await_fast_event()
  if not window:is_valid() then
    console.debug(
      'Window on which blame was live blame was being synced is no longer valid'
    )
    return
  end
  loop.await_fast_event()
  local new_lnum = window:get_lnum()
  if lnum ~= new_lnum then
    console.debug(
      string.format(
        'Suspending blame computation for %s user is currently on %s and not in %s',
        buffer.bufnr,
        new_lnum,
        lnum
      )
    )
    return
  end
  if blame_err then
    console.debug(blame_err, debug.traceback())
    return
  end
  loop.await_fast_event()
  local config_err, config = buffer.git_object:config()
  if config_err then
    console.debug(config_err, debug.traceback())
    return
  end
  self:hide(buffer)
  self:display(lnum, buffer, config, blame)
  self.last_lnum = lnum
end))

function LiveBlame:desync(force)
  loop.await_fast_event()
  local window = Window:new(0)
  local buffer = self.git_store:current()
  if not buffer then
    return
  end
  loop.await_fast_event()
  buffer = self.git_store:get(buffer)
  loop.await_fast_event()
  local lnum = window:get_lnum()
  if not force and self.last_lnum and self.last_lnum == lnum then
    return
  end
  self:hide(buffer)
end

function LiveBlame:desync_all()
  local buffers = Buffer:list()
  for i = 1, #buffers do
    self:hide(buffers[i])
  end
end

return LiveBlame
