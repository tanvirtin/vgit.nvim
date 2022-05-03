local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local versioning = require('vgit.core.versioning')

local Feature = Object:extend()

function Feature:constructor()
  return {
    name = 'Feature',
  }
end

function Feature:guard()
  local neovim_version = versioning.neovim_version()
  local requires_version = self.requires_neovim_version
  local result = versioning.guard(requires_version)

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

return Feature
