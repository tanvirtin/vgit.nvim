local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local Buffer = require('vgit.core.Buffer')
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
  event.on(event_type.BufAdd, function() self:attach() end)

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
  if not buffer:is_valid() then
    return
  end

  loop.await()
  local live_signs = buffer:get_cached_live_signs()

  loop.await()
  buffer:clear_cached_live_signs()

  loop.await()
  local err = buffer.git_blob:live_hunks(buffer:get_lines())

  if err then
    loop.await()
    buffer:set_cached_live_signs(live_signs)
    console.debug.error(err)

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

LiveGutter.resync = loop.async(function(self, buffer)
  loop.await()
  buffer = buffer or git_service.store.current()

  if buffer then
    self:sync(buffer)
  end
end)

function LiveGutter:watch(buffer)
  buffer:watch_file(function()
    buffer:sync()
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

function LiveGutter:attach()
  loop.await()
  local buffer = Buffer(0)

  loop.await()
  if git_service.store.contains(buffer) then
    return
  end

  loop.await()
  buffer:sync_git()

  local _, is_inside_git_dir = buffer.git_blob:is_inside_git_dir()
  loop.await()

  if not is_inside_git_dir then
    self:resync(buffer)
    return
  end

  loop.await()
  if not buffer:is_valid() then
    return
  end

  loop.await()
  if not buffer:is_in_disk() then
    return
  end

  loop.await()
  local _, is_ignored = buffer.git_blob:is_ignored()

  if is_ignored then
    return
  end

  loop.await()
  git_service.store.add(buffer)
  loop.await()

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

      on_detach = loop.async(function() self:detach(buffer) end),
    })
    :attach_to_renderer(function(top, bot) self:render(buffer, top, bot) end)

  self:sync(buffer)
  self:watch(buffer)
end

function LiveGutter:detach(buffer)
  git_service.store.remove(buffer, function() buffer:unwatch_file():detach_from_renderer() end)

  return self
end

return LiveGutter
