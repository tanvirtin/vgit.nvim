local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')

local Mutation = Object:extend()

function Mutation:constructor() return { git = Git() } end

function Mutation:stash_apply(index) return self.git:stash_apply(index) end

function Mutation:stash_drop(index) return self.git:stash_drop(index) end

function Mutation:stash_pop(index) return self.git:stash_pop(index) end

function Mutation:stash_clear(index) return self.git:stash_clear(index) end

return Mutation
