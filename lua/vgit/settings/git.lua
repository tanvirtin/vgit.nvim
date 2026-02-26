local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  cmd = 'git',
  algorithm = 'myers',
  fallback_cwd = '',
  fallback_args = {},
})
