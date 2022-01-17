local live_gutter_setting = require('vgit.settings.live_gutter')
local loop = require('vgit.core.loop')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local Feature = require('vgit.Feature')

local LiveGutter = Feature:extend()

function LiveGutter:new(git_store, versioning)
  return setmetatable({
    name = 'Live Gutter',
    git_store = git_store,
    versioning = versioning,
  }, LiveGutter)
end

LiveGutter.hide = loop.async(function(_, buffer)
  loop.await_fast_event()
  if buffer:is_rendering() then
    return
  end
  buffer:sign_unplace()
end)

LiveGutter.sync = loop.brakecheck(
  loop.async(function(self, buffer)
    local live_signs = buffer:clear_cached_live_signs()
    buffer:clear_cached_live_signs()
    loop.await_fast_event()
    local err = buffer.git_object:live_hunks(buffer:get_lines())
    if err then
      buffer:set_cached_live_signs(live_signs)
      console.debug(err, debug.traceback())
      return
    end
    local hunks = buffer.git_object.hunks
    if not hunks then
      buffer:set_cached_live_signs(live_signs)
      return
    end
    self:hide(buffer)
    for i = 1, #hunks do
      loop.await_fast_event()
      buffer:cache_live_sign(hunks[i])
    end
  end),
  {
    initial_ms = 0,
    cutoff_ms = 30,
    step_ms = 1,
  }
)

LiveGutter.resync = loop.async(function(self, buffer)
  loop.await_fast_event()
  buffer = buffer or self.git_store:current()
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

function LiveGutter:on_render(buffer, top, bot)
  if not live_gutter_setting:get('enabled') then
    return
  end
  local hunks = buffer.git_object.hunks
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
  loop.await_fast_event()
  local buffer = Buffer:new(0)
  if self:is_buffer_in_git_store(buffer) then
    return
  end
  loop.await_fast_event()
  buffer:sync_git()
  if not self:is_inside_git_dir(buffer) then
    self:resync(buffer)
    return
  end
  if not self:is_buffer_valid(buffer) then
    return
  end
  if not self:is_buffer_in_disk(buffer) then
    return
  end
  if self:is_buffer_ignored(buffer) then
    return
  end
  loop.await_fast_event()
  self.git_store:add(buffer)
  loop.await_fast_event()
  buffer
    :attach_to_changes({
      on_lines = loop.async(function(_, _, _, _, p_lnum, n_lnum, byte_count)
        loop.await_fast_event()
        if p_lnum == n_lnum and byte_count == 0 then
          return
        end
        self:sync(buffer)
      end),
      on_reload = loop.async(function()
        loop.await_fast_event()
        self:sync(buffer)
      end),
      on_detach = loop.async(function()
        self:detach(buffer)
      end),
    })
    :attach_to_renderer(function(top, bot)
      self:on_render(buffer, top, bot)
    end)
  self:sync(buffer)
  self:watch(buffer)
end

function LiveGutter:detach(buffer)
  self.git_store:remove(buffer, function()
    buffer:unwatch_file():detach_from_renderer()
  end)
  return self
end

return LiveGutter
