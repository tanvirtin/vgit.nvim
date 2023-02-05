local loop = require('vgit.core.loop')
local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local Namespace = require('vgit.core.Namespace')
local event_type = require('vgit.core.event_type')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_blame_setting = require('vgit.settings.live_blame')

local LiveBlame = Object:extend()

function LiveBlame:constructor()
  return {
    id = 1,
    name = 'Live Blame',
    namespace = Namespace(),
    last_lnum = nil,
    git = Git(),
  }
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

function LiveBlame:reset()
  git_buffer_store.for_each(function(git_buffer) self:clear(git_buffer) end)
end

function LiveBlame:render(git_buffer)
  if not live_blame_setting:get('enabled') then
    return
  end

  git_buffer = git_buffer or git_buffer_store.current()

  if not git_buffer then
    return
  end

  loop.await()
  local config_err, config = self.git:config()

  if config_err then
    console.debug.error(config_err)
    return
  end

  loop.await()
  local window = Window(0)
  loop.await()
  local lnum = window:get_lnum()

  if self.last_lnum == lnum then
    return
  end

  loop.await()
  local blame_err, blame = git_buffer.git_object:blame_line(lnum)

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

  self:clear(git_buffer)
  self:display(lnum, git_buffer, config, blame)
  self.last_lnum = lnum
end

function LiveBlame:register_events()
  git_buffer_store.attach('attach', function(git_buffer)
    git_buffer
      :on(event_type.BufEnter, function() self:reset() end)
      :on(event_type.WinEnter, function() self:reset() end)
      :on(event_type.CursorMoved, function() self:reset() end)
      :on(event_type.InsertEnter, function() self:reset() end)
      :on(event_type.CursorHold, function() self:render() end)
  end)

  return self
end

return LiveBlame
