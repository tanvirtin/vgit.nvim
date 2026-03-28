local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')

return function(filepath, repo_path)
  if not filepath or filepath == '' then return filepath end
  local absolute = vim.fn.fnamemodify(filepath, ':p')
  return fs.make_relative(repo_path, absolute)
end
