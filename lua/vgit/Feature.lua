local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local console = require('vgit.core.console')
local Object = require('vgit.core.Object')

local Feature = Object:extend()

function Feature:new(git_store, versioning)
  return setmetatable({
    name = 'Feature',
    git_store = git_store,
    versioning = versioning,
  }, Feature)
end

function Feature:guard()
  local neovim_version = self.versioning:neovim_version()
  local requires_version = self.requires_neovim_version
  local result = self.versioning:guard(requires_version)
  if not result then
    console.info(
      string.format(
        'Current Neovim version %s.%s.%s is incompatible with %s, which requires version %s.%s.%s and up. Please disable %s to stop seeing this message.',
        neovim_version.major,
        neovim_version.minor,
        neovim_version.patch,
        self.name,
        requires_version.major,
        requires_version.minor,
        requires_version.patch,
        self.name
      )
    )
  end
  return result
end

function Feature:is_buffer_valid(buffer)
  loop.await_fast_event()
  if not buffer:is_valid() then
    console.debug(string.format('The buffer %s is invalid', buffer.filename))
    return false
  end
  return true
end

function Feature:is_buffer_in_git_store(buffer)
  loop.await_fast_event()
  if not self.git_store:contains(buffer) then
    console.debug(
      string.format('The buffer %s not in git store', buffer.filename)
    )
    return false
  end
  return true
end

function Feature:is_buffer_in_disk(buffer)
  loop.await_fast_event()
  local filename = buffer.filename
  if not filename or filename == '' then
    console.debug(
      string.format('The buffer #%s does not have a filename', buffer.bufnr)
    )
    return false
  end
  loop.await_fast_event()
  if not fs.exists(filename) then
    console.debug(
      string.format('The buffer %s does exist in disk', buffer.filename)
    )
    return
  end
  return true
end

function Feature:is_inside_git_dir(buffer)
  loop.await_fast_event()
  local is_inside_git_dir = buffer.git_object:is_inside_git_dir()
  loop.await_fast_event()
  if not is_inside_git_dir then
    console.debug(
      'Live gutter feature is disabled, we are not in a git repository'
    )
    return false
  end
  return true
end

function Feature:is_buffer_ignored(buffer)
  loop.await_fast_event()
  local is_ignored = buffer.git_object:is_ignored()
  loop.await_fast_event()
  if is_ignored then
    console.debug(
      string.format(
        'The buffer %s will be ignored, match found in .gitignore',
        buffer.filename
      )
    )
    return true
  end
  return false
end

function Feature:is_buffer_tracked(buffer)
  loop.await_fast_event()
  local tracked_filename = buffer.git_object:tracked_filename()
  loop.await_fast_event()
  if tracked_filename == '' then
    console.debug(
      string.format('The buffer %s is not tracked', buffer.filename)
    )
    return false
  end
  return true
end

return Feature
