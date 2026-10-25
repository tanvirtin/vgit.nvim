local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  cmd = 'git',
  algorithm = 'myers',
  fallback_cwd = '',
  fallback_args = {},
  auto_repository_detection = true,
  repository_scan_max_depth = 1,
  repository_scan_ignored_folders = { 'node_modules' },
})
