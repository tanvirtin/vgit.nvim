local console = require('vgit.core.console')
local Object = require('vgit.core.Object')

local Versioning = Object:extend()

function Versioning:new()
  return setmetatable({
    history = {
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
    },
  }, Versioning)
end

function Versioning:guard(version)
  if version then
    local neovim_version = self:neovim_version()
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

function Versioning:current()
  return self.history[#self.history]
end

function Versioning:previous()
  return self.history[#self.history - 1]
end

function Versioning:neovim_version()
  return vim.version()
end

function Versioning:is_neovim_compatible()
  if self:guard({
    patch = 0,
    minor = 5,
    major = 0,
  }) then
    return true
  end
  local neovim_version = self:neovim_version()
  local plugin_version = self:current()
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

return Versioning
