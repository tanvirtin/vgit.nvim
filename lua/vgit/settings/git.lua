local Config = require('vgit.core.Config')

return Config({
  cmd = 'git',
  fallback_cwd = '',
  fallback_args = {},
})
