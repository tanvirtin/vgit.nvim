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
    },
  }, Versioning)
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
  local plugin_version = self:current()
  local expected_neovim_version = {
    patch = 0,
    minor = 5,
    major = 0,
  }
  local actual_neovim_version = self:neovim_version()
  if
    actual_neovim_version.patch >= expected_neovim_version.patch
    and actual_neovim_version.minor >= expected_neovim_version.minor
    and actual_neovim_version.major >= expected_neovim_version.major
  then
    return true
  end
  console.info(
    string.format(
      'Current Neovim version %s.%s is incompatible with VGit %s.%s.',
      actual_neovim_version.major,
      actual_neovim_version.minor,
      plugin_version.major,
      plugin_version.minor
    )
  )
  return false
end

return Versioning
