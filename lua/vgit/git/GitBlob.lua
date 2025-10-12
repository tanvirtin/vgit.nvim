local Object = require('vgit.core.Object')

local GitBlob = Object:extend()

function GitBlob:constructor(repo, filename, commit)
  if not repo then error('GitBlob: repo_path is required') end

  if not filename or filename == '' then error('GitBlob: filename is required') end

  local repo_path = type(repo) == 'string' and repo or repo:get_path()

  return {
    _repo_path = repo_path,
    _filename = filename,
    _commit = commit or 'HEAD',
  }
end

function GitBlob:get_filename()
  return self._filename
end

function GitBlob:get_commit()
  return self._commit
end

function GitBlob:exists()
  local git_repo = require('vgit.git.git_repo')
  local result, err = git_repo.has(self._repo_path, self._filename, self._commit)
  if err then return nil, err end
  return result, nil
end

function GitBlob:content()
  local git_show = require('vgit.git.git_show')
  local content, err = git_show.content(self._repo_path, self._filename, self._commit)

  if err then return nil, err end
  return content, nil
end

function GitBlob:lines()
  local git_show = require('vgit.git.git_show')
  local result, err = git_show.lines(self._repo_path, self._filename, self._commit)
  if err then return nil, err end
  return result, nil
end

function GitBlob:size()
  local content, err = self:content()
  if err then return nil, err end
  if not content then return 0, nil end
  return #content, nil
end

function GitBlob:hash()
  local git_show = require('vgit.git.git_show')
  local result, err = git_show.hash(self._repo_path, self._filename, self._commit)
  if err then return nil, err end
  return result, nil
end

return GitBlob
