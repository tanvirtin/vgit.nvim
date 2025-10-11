local Object = require('vgit.core.Object')
local git_stager = require('vgit.git.git_stager')
local git_status = require('vgit.git.git_status')
local git_hunks = require('vgit.git.git_hunks')
local git_commit = require('vgit.git.git_commit')

local GitIndex = Object:extend()

function GitIndex:constructor(repository)
  if not repository then error('GitIndex requires a repository') end

  local index = {
    _repository = repository,
    _staged_files = nil,
  }

  return index
end

function GitIndex:repository()
  return self._repository
end

function GitIndex:add(filename)
  local _, err = git_stager.stage(self._repository:get_path(), filename)
  if err then return nil, err end

  self._staged_files = nil

  return true, nil
end

function GitIndex:add_all()
  return self:add(nil)
end

function GitIndex:remove(filename)
  local _, err = git_stager.unstage(self._repository:get_path(), filename)
  if err then return nil, err end

  self._staged_files = nil

  return true, nil
end

function GitIndex:reset()
  return self:remove(nil)
end

function GitIndex:add_hunk(filename, hunk)
  if not filename then return nil, { 'filename is required' } end

  if not hunk then return nil, { 'hunk is required' } end

  local _, err = git_stager.stage_hunk(self._repository:get_path(), filename, hunk)
  if err then return nil, err end

  self._staged_files = nil

  return true, nil
end

function GitIndex:remove_hunk(filename, hunk)
  if not filename then return nil, { 'filename is required' } end

  if not hunk then return nil, { 'hunk is required' } end

  local _, err = git_stager.unstage_hunk(self._repository:get_path(), filename, hunk)
  if err then return nil, err end

  self._staged_files = nil

  return true, nil
end

function GitIndex:status()
  return git_status.ls(self._repository:get_path())
end

function GitIndex:file_status(filename)
  if not filename then return nil, { 'filename is required' } end

  return git_status.ls(self._repository:get_path(), filename)
end

function GitIndex:staged_files()
  if not self._staged_files then
    local all_files, err = self:status()
    if err then return nil, err end

    local staged = {}
    for _, file in ipairs(all_files) do
      if file:is_staged() then staged[#staged + 1] = file end
    end

    self._staged_files = staged
  end

  return self._staged_files, nil
end

function GitIndex:unstaged_files()
  local all_files, err = self:status()
  if err then return nil, err end

  local unstaged = {}
  for _, file in ipairs(all_files) do
    if file:is_unstaged() then unstaged[#unstaged + 1] = file end
  end

  return unstaged, nil
end

function GitIndex:unmerged_files()
  local all_files, err = self:status()
  if err then return nil, err end

  local unmerged = {}
  for _, file in ipairs(all_files) do
    if file:is_unmerged() then unmerged[#unmerged + 1] = file end
  end

  return unmerged, nil
end

function GitIndex:staged_hunks(filename)
  return git_hunks.list(self._repository:get_path(), {
    staged = true,
    filename = filename,
  })
end

function GitIndex:unstaged_hunks(filename)
  return git_hunks.list(self._repository:get_path(), {
    staged = false,
    filename = filename,
  })
end

function GitIndex:has_staged_changes()
  local staged, err = self:staged_files()
  if err then return nil, err end
  return #staged > 0, nil
end

function GitIndex:has_unstaged_changes()
  local unstaged, err = self:unstaged_files()
  if err then return nil, err end
  return #unstaged > 0, nil
end

function GitIndex:is_clean()
  local files, err = self:status()
  if err then return nil, err end
  return #files == 0, nil
end

function GitIndex:commit(message)
  if not message or message == '' then return nil, { 'commit message is required' } end

  local has_changes, err = self:has_staged_changes()
  if err then return nil, err end
  if not has_changes then return nil, { 'no staged changes to commit' } end

  local success, commit_err = git_commit.create(self._repository:get_path(), message)
  if commit_err then return nil, commit_err end

  self._staged_files = nil

  return success, nil
end

function GitIndex:can_commit()
  local result, err = self:has_staged_changes()
  if err then return nil, err end
  return result, nil
end

function GitIndex:commit_dry_run()
  return git_commit.dry_run(self._repository:get_path())
end

function GitIndex:reset_cache()
  self._staged_files = nil
end

return GitIndex
