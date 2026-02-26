local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local git_repo = lazy('vgit.git.git_repo')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local GitRef = Object:extend()

function GitRef:constructor(repository)
  if not repository then error('GitRef requires a repository') end

  local refs = {
    _repo_path = repository:get_path(),
    _branches = nil,
    _tags = nil,
    _current = nil,
  }

  return refs
end

function GitRef:current()
  if not self._current then
    local result, err = GitQueryBuilder(self._repo_path):raw_args('rev-parse', '--abbrev-ref', 'HEAD'):execute()

    if err then return nil, err end

    local branch_name = result[1]

    local hash_result, hash_err = GitQueryBuilder(self._repo_path):raw_args('rev-parse', 'HEAD'):execute()

    if hash_err then return nil, hash_err end

    self._current = {
      name = branch_name,
      hash = hash_result[1],
      is_detached = branch_name == 'HEAD',
    }
  end

  return self._current, nil
end

function GitRef:current_branch()
  local current, err = self:current()
  if err then return nil, err end
  return current.name, nil
end

function GitRef:head()
  local current, err = self:current()
  if err then return nil, err end
  return current.hash, nil
end

function GitRef:is_detached()
  local current, err = self:current()
  if err then return nil, err end
  return current and current.is_detached or false, nil
end

function GitRef:branches(opts)
  opts = opts or {}

  local query =
    GitQueryBuilder(self._repo_path):raw_args('branch', '--list', '--format=%(refname:short)\x1F%(objectname)')

  if opts.all then
    query:raw_arg('--all')
  elseif opts.remote then
    query:raw_arg('--remotes')
  end

  local result, err = query:execute()
  if err then return nil, err end

  local branches = {}
  for _, line in ipairs(result) do
    local parts = vim.split(line, '\x1F')
    if #parts >= 2 then
      branches[#branches + 1] = {
        name = parts[1],
        hash = parts[2],
        is_remote = opts.remote or (opts.all and parts[1]:match('^remotes/')),
      }
    end
  end

  self._branches = branches
  return branches, nil
end

function GitRef:local_branches()
  return self:branches({ remote = false })
end

function GitRef:remote_branches()
  return self:branches({ remote = true })
end

function GitRef:tags()
  if not self._tags then
    local result, err =
      GitQueryBuilder(self._repo_path):raw_args('tag', '--list', '--format=%(refname:short)\x1F%(objectname)'):execute()

    if err then return nil, err end

    local tags = {}
    for _, line in ipairs(result) do
      local parts = vim.split(line, '\x1F')
      if #parts >= 2 then tags[#tags + 1] = {
        name = parts[1],
        hash = parts[2],
      } end
    end

    self._tags = tags
  end

  return self._tags, nil
end

function GitRef:get(name)
  if not name then return nil, { 'name is required' } end

  local result, err = GitQueryBuilder(self._repo_path):raw_args('rev-parse', '--verify', name):execute()

  if err then return nil, err end

  return {
    name = name,
    hash = result[1],
  }, nil
end

function GitRef:branch_exists(name)
  if not name then return nil, { 'name is required' } end

  local _, err =
    GitQueryBuilder(self._repo_path):raw_args('rev-parse', '--verify', string.format('refs/heads/%s', name)):execute()

  return err == nil, nil
end

function GitRef:tag_exists(name)
  if not name then return nil, { 'name is required' } end

  local _, err =
    GitQueryBuilder(self._repo_path):raw_args('rev-parse', '--verify', string.format('refs/tags/%s', name)):execute()

  return err == nil, nil
end

function GitRef:create_branch(name, start_point)
  if not name then return nil, { 'branch name is required' } end

  local query = GitQueryBuilder(self._repo_path):raw_args('branch', name)

  if start_point then query:raw_arg(start_point) end

  local _, err = query:execute()
  if err then return nil, err end

  self._branches = nil

  return true, nil
end

function GitRef:delete_branch(name, force)
  if not name then return nil, { 'branch name is required' } end

  local _, err = GitQueryBuilder(self._repo_path):raw_args('branch', force and '-D' or '-d', name):execute()

  if err then return nil, err end

  self._branches = nil

  return true, nil
end

function GitRef:checkout(name)
  if not name then return nil, { 'name is required' } end

  local _, err = git_repo.checkout(self._repo_path, name)
  if err then return nil, err end

  self._current = nil

  return true, nil
end

function GitRef:checkout_new_branch(name, start_point)
  if not name then return nil, { 'branch name is required' } end

  local query = GitQueryBuilder(self._repo_path):raw_args('checkout', '-b', name)

  if start_point then query:raw_arg(start_point) end

  local _, err = query:execute()
  if err then return nil, err end

  self._current = nil
  self._branches = nil

  return true, nil
end

function GitRef:create_tag(name, commit, message)
  if not name then return nil, { 'tag name is required' } end

  local query = GitQueryBuilder(self._repo_path):raw_arg('tag')

  if message then
    query:raw_arg('-a')
    query:raw_arg(name)
    query:raw_arg('-m')
    query:raw_arg(message)
  else
    query:raw_arg(name)
  end

  if commit then query:raw_arg(commit) end

  local _, err = query:execute()
  if err then return nil, err end

  self._tags = nil

  return true, nil
end

function GitRef:delete_tag(name)
  if not name then return nil, { 'tag name is required' } end

  local _, err = GitQueryBuilder(self._repo_path):raw_args('tag', '-d', name):execute()

  if err then return nil, err end

  self._tags = nil

  return true, nil
end

function GitRef:reset_cache()
  self._branches = nil
  self._tags = nil
  self._current = nil
end

return GitRef
