local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local GitBuffer = require('vgit.git.GitBuffer')
local git_buffer_store = require('vgit.git.git_buffer_store')
local live_gutter_setting = require('vgit.settings.live_gutter')

local LiveGutter = Object:extend()

function LiveGutter:constructor()
  return {
    name = 'Live Gutter',
  }
end

LiveGutter.clear = loop.async(function(self, buffer)
  loop.await()

  if buffer:is_rendering() then
    return self
  end

  buffer:sign_unplace()

  return self
end)

function LiveGutter:reset()
  local buffers = GitBuffer:list()

  for i = 1, #buffers do
    local buffer = buffers[i]

    if buffer then
      self:clear(buffer)
    end
  end
end

LiveGutter.fetch = loop.debounced_async(function(self, buffer)
  loop.await()
  if not buffer:is_valid() then
    return self
  end

  loop.await()
  local live_signs = buffer:get_cached_live_signs()

  loop.await()
  buffer:clear_cached_live_signs()

  loop.await()
  local err = buffer.git_object:live_hunks(buffer:get_lines())

  if err then
    loop.await()
    buffer:set_cached_live_signs(live_signs)
    console.debug.error(err)

    return self
  end

  local hunks = buffer.git_object.hunks

  if not hunks then
    loop.await()
    buffer:set_cached_live_signs(live_signs)

    return self
  else
    local diff_status = buffer.git_object:generate_diff_status()

    loop.await()
    buffer:set_var('vgit_status', diff_status)
  end

  loop.await()
  self:clear(buffer)

  for i = 1, #hunks do
    loop.await()
    buffer:cache_live_sign(hunks[i])
  end

  return self
end, 50)

function LiveGutter:render(buffer, top, bot)
  if not live_gutter_setting:get('enabled') then
    return self
  end

  local hunks = buffer.git_object.hunks

  if not hunks then
    return self
  end

  local cached_live_signs = buffer:get_cached_live_signs()
  local gutter_signs = {}

  for i = top, bot do
    gutter_signs[#gutter_signs + 1] = cached_live_signs[i]
  end

  buffer:sign_placelist(gutter_signs)
end

function LiveGutter:register_events()
  git_buffer_store
    .attach('attach', function(git_buffer) self:fetch(git_buffer) end)
    .attach('reload', function(git_buffer)
      loop.await()
      self:fetch(git_buffer)
    end)
    .attach('change', function(git_buffer, p_lnum, n_lnum, byte_count)
      if p_lnum == n_lnum and byte_count == 0 then
        return
      end
      loop.await()
      self:fetch(git_buffer)
    end)
    .attach('watch', function(git_buffer)
      git_buffer:sync()
      self:fetch(git_buffer)
    end)
    .attach('git_watch', function(git_buffers)
      for i = 1, #git_buffers do
        self:fetch(git_buffers[i])
      end
    end)
    .attach('render', function(git_buffer, top, bot) self:render(git_buffer, top, bot) end)

  return self
end

return LiveGutter
