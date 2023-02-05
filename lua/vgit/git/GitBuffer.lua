local loop = require('vgit.core.loop')
local Buffer = require('vgit.core.Buffer')
local GitObject = require('vgit.git.GitObject')
local signs_setting = require('vgit.settings.signs')

local GitBuffer = Buffer:extend()

function GitBuffer:sync()
  Buffer.sync(self)

  self.git_object = GitObject(self.filename)
  self.live_signs = {}
  self.is_processing = false
  self.is_showing_lens = false

  return self
end

function GitBuffer:set_cached_live_signs(live_signs)
  self.state.live_signs = live_signs

  return self
end

function GitBuffer:get_cached_live_signs() return self.state.live_signs end

function GitBuffer:clear_cached_live_signs()
  self.state.live_signs = {}

  return self
end

function GitBuffer:cache_live_sign(hunk)
  local bufnr = self.bufnr
  local live_signs = self:get_cached_live_signs()
  local sign_priority = signs_setting:get('priority')
  local sign_group = self.namespace:get_sign_ns_id(self)
  local sign_types = signs_setting:get('usage').main

  for j = hunk.top, hunk.bot do
    local lnum = (hunk.type == 'remove' and j == 0) and 1 or j

    live_signs[lnum] = {
      id = lnum,
      lnum = lnum,
      buffer = bufnr,
      group = sign_group,
      name = sign_types[hunk.type],
      priority = sign_priority,
    }
  end

  return self
end

function GitBuffer:is_inside_git_dir()
  loop.free_textlock()
  local is_inside_git_dir = self.git_object:is_inside_git_dir()
  loop.free_textlock()

  if not is_inside_git_dir then
    return false
  end

  return true
end

function GitBuffer:is_ignored()
  loop.free_textlock()
  local is_ignored = self.git_object:is_ignored()
  loop.free_textlock()

  if is_ignored then
    return true
  end

  return false
end

function GitBuffer:is_tracked()
  loop.free_textlock()
  local tracked_filename = self.git_object:tracked_filename()
  loop.free_textlock()

  if tracked_filename == '' then
    return false
  end

  return true
end

return GitBuffer
