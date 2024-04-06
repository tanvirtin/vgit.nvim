local git_repo = require('vgit.git.git2.repo')
local Buffer = require('vgit.core.Buffer')
local GitObject = require('vgit.git.GitObject')
local signs_setting = require('vgit.settings.signs')

local GitBuffer = Buffer:extend()

function GitBuffer:sync()
  Buffer.sync(self)

  self.signs = {}
  self.is_processing = false
  self.is_showing_lens = false
  self.git_object = GitObject(self:get_name())

  return self
end

function GitBuffer:config()
  return self.git_object:config()
end

function GitBuffer:is_ignored()
  return self.git_object:is_ignored()
end

function GitBuffer:is_tracked()
  return self.git_object:is_tracked()
end

function GitBuffer:is_inside_git_dir()
  return git_repo.exists(self:get_name())
end

function GitBuffer:generate_status()
  return self:set_var('vgit_status', self.git_object:generate_status())
end

function GitBuffer:blame(lnum)
  return self.git_object:blame(lnum)
end

function GitBuffer:blames()
  return self.git_object:blames()
end

function GitBuffer:live_hunks()
  local lines = self:get_lines()
  local err, hunks = self.git_object:live_hunks(lines)

  if err then return err end

  local sign_types = signs_setting:get('usage').main
  local sign_priority = signs_setting:get('priority')
  local sign_group = self.namespace:get_sign_ns_id(self)

  self.signs = {}
  for i = 1, #hunks do
    local hunk = hunks[i]
    for j = hunk.top, hunk.bot do
      local lnum = (hunk.type == 'remove' and j == 0) and 1 or j
      self.signs[lnum] = {
        id = lnum,
        lnum = lnum,
        buffer = self.bufnr,
        group = sign_group,
        name = sign_types[hunk.type],
        priority = sign_priority,
      }
    end
  end

  return nil, hunks
end

return GitBuffer
