local console = require('vgit.core.console')

local history = {
  {
    patch = 0,
    minor = 0,
    major = 0,
  },
  {
    patch = 0,
    minor = 1,
    major = 0,
  },
  {
    patch = 1,
    minor = 1,
    major = 0,
  },
}

local versioning = {}

function versioning.guard(version)
  if version then
    local neovim_version = versioning.neovim_version()
    if
      neovim_version.patch >= version.patch
      and neovim_version.minor >= version.minor
      and neovim_version.major >= version.major
    then
      return true
    end
    return false
  end
  return true
end

function versioning.current()
  return history[#history]
end

function versioning.previous()
  return history[#history - 1]
end

function versioning.neovim_version()
  return vim.version()
end

function versioning.is_neovim_compatible()
  if versioning.guard({
    patch = 0,
    minor = 5,
    major = 0,
  }) then
    return true
  end
  local neovim_version = versioning.neovim_version()
  local plugin_version = versioning.current()
  console.info(
    string.format(
      'Current Neovim version %s.%s.%s is incompatible with VGit %s.%s.%s',
      neovim_version.major,
      neovim_version.minor,
      neovim_version.patch,
      plugin_version.major,
      plugin_version.minor,
      plugin_version.patch
    )
  )
  return false
end

return versioning
