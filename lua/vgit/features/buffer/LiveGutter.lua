local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local git_service = require('vgit.services.git')
local event_type = require('vgit.core.event_type')
local live_gutter_setting = require('vgit.settings.live_gutter')

local LiveGutter = Object:extend()

function LiveGutter:constructor()
  return {
    name = 'Live Gutter',
  }
end

function LiveGutter:register_events()
  event.custom_on(event_type.VGitBufAttached, function(event_data) self:attach(event_data.data) end)

  return self
end

LiveGutter.clear = loop.async(function(_, buffer)
  loop.await()
  if buffer:is_rendering() then
    return
  end

  buffer:sign_unplace()
end)

LiveGutter.sync = loop.debounced_async(function(self, buffer)
  loop.await()
  buffer = buffer or git_service.store.current()

  loop.await()
  if not buffer then
    return
  end

  loop.await()
  if not buffer:is_valid() then
    return
  end

  loop.await()
  local live_signs = buffer:get_cached_live_signs()

  loop.await()
  if not buffer:is_valid() then
    return
  end

  loop.await()
  buffer:clear_cached_live_signs()

  loop.await()
  if not buffer:is_valid() then
    return
  end

  loop.await()
  local err = buffer.git_blob:live_hunks(buffer:get_lines())

  if err then
    loop.await()
    buffer:set_cached_live_signs(live_signs)
    console.debug.error(err)

    return
  end

  if not buffer:is_valid() then
    return
  end

  local hunks = buffer.git_blob.hunks

  if not hunks then
    loop.await()
    buffer:set_cached_live_signs(live_signs)

    return
  else
    local diff_status = buffer.git_blob:generate_diff_status()

    loop.await()
    buffer:set_var('vgit_status', diff_status)
  end

  loop.await()
  self:clear(buffer)

  for i = 1, #hunks do
    loop.await()
    buffer:cache_live_sign(hunks[i])
  end
end, 20)

function LiveGutter:watch(buffer)
  buffer:watch_file(function()
    buffer:sync(git_service)
    self:sync(buffer)
  end)
end

function LiveGutter:render(buffer, top, bot)
  if not live_gutter_setting:get('enabled') then
    return
  end

  local hunks = buffer.git_blob.hunks

  if not hunks then
    return
  end

  local cached_live_signs = buffer:get_cached_live_signs()
  local gutter_signs = {}

  for i = top, bot do
    gutter_signs[#gutter_signs + 1] = cached_live_signs[i]
  end

  buffer:sign_placelist(gutter_signs)
end

function LiveGutter:attach(buffer)
  loop.await()
  buffer = git_service.store.get(buffer)

  buffer
    :attach_to_changes({
      on_lines = loop.async(function(_, _, _, _, p_lnum, n_lnum, byte_count)
        if p_lnum == n_lnum and byte_count == 0 then
          return
        end

        loop.await()
        self:sync(buffer)
      end),

      on_reload = loop.async(function()
        loop.await()
        self:sync(buffer)
      end),
    })
    :attach_to_renderer(function(top, bot) self:render(buffer, top, bot) end)

  self:sync(buffer)
  self:watch(buffer)
end

return LiveGutter
