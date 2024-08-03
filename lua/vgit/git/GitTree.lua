local Object = require('vgit.core.Object')

local GitTree = Object:extend()

function GitTree:constructor()
  return {}
end

function GitTree:entries(commit_hash) end

return GitTree
