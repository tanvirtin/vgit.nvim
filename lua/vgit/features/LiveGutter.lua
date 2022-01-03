local signs_setting = require('vgit.settings.signs')
local live_gutter_setting = require('vgit.settings.live_gutter')
local loop = require('vgit.core.loop')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local Feature = require('vgit.Feature')

local LiveGutter = Feature:extend()

function LiveGutter:new(git_store)
  return setmetatable({ git_store = git_store }, LiveGutter)
end

LiveGutter.sync = loop.brakecheck(
  loop.async(function(self, buffer)
    loop.await_fast_event()
    local err = buffer.git_object:live_hunks(buffer:get_lines())
    if err then
      console.debug(err, debug.traceback())
      return
    end
    self:hide(buffer)
    self:display(buffer)
  end),
  {
    initial_ms = 50,
    cutoff_ms = 100,
    step_ms = 10,
  }
)

LiveGutter.resync = loop.brakecheck(loop.async(function(self)
  loop.await_fast_event()
  local buffer = self.git_store:current()
  if buffer then
    self:sync(buffer)
  end
end))

function LiveGutter:watch(buffer)
  buffer.watcher = loop.watch(
    buffer.filename,
    loop.async(function(err)
      loop.await_fast_event()
      if err then
        console.debug(
          string.format('Error encountered while watching %s', buffer.filename)
        )
        return
      end
      loop.await_fast_event()
      -- Deleting a buffer also triggers this event, so we need to check if the buffer is still valid
      if buffer:is_valid() then
        buffer:sync()
        self:sync(buffer)
      end
    end)
  )
end

function LiveGutter:display(buffer)
  loop.await_fast_event()
  if not live_gutter_setting:get('enabled') then
    return
  end
  local hunks = buffer.git_object.hunks
  if not hunks then
    return
  end
  for i = 1, #hunks do
    local hunk = hunks[i]
    for j = hunk.start, hunk.finish do
      buffer:sign_place(
        (hunk.type == 'remove' and j == 0) and 1 or j,
        signs_setting:get('usage').main[hunk.type]
      )
    end
  end
end

function LiveGutter:hide(buffer)
  loop.await_fast_event()
  buffer:sign_unplace()
end

function LiveGutter:attach()
  loop.await_fast_event()
  local buffer = Buffer:new(0)
  loop.await_fast_event()
  buffer:sync_git()
  loop.await_fast_event()
  if not self:is_inside_git_dir(buffer) then
    return
  end
  loop.await_fast_event()
  if not self:is_buffer_valid(buffer) then
    return
  end
  loop.await_fast_event()
  if not self:is_buffer_in_disk(buffer) then
    return
  end
  loop.await_fast_event()
  if self:is_buffer_ignored(buffer) then
    return
  end
  loop.await_fast_event()
  self.git_store:add(buffer)
  loop.await_fast_event()
  buffer:attach({
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
  })
  self:sync(buffer)
  self:watch(buffer)
end

function LiveGutter:detach()
  self.git_store:clean(function(buffer)
    loop.unwatch(buffer.watcher)
  end)
end

return LiveGutter
