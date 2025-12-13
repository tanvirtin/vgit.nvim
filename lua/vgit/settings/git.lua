local Config = require('vgit.core.Config')

return Config({
  cmd = 'git',
  algorithm = 'myers',
  fallback_cwd = '',
  fallback_args = {},
})
