local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git2.log')
local git_show = require('vgit.git.git2.show')
local git_repo = require('vgit.git.git2.repo')
local git_hunks = require('vgit.git.git2.hunks')
local GitObject = require('vgit.git.GitObject')
local diff_service = require('vgit.services.diff')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    shape = nil,
    git_object = nil,
    _cache = {
      blame = nil,
      diff_dto = nil,
    },
  }
end

function Store:reset()
  self.err = nil
  self._cache = {
    blame = nil,
    diff_dto = nil,
  }

  return self
end

function Store:fetch(shape, filename, lnum, opts)
  opts = opts or {}

  if not filename or filename == '' then return { 'Buffer has no blame associated with it' }, nil end

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)

  loop.free_textlock()
  self._cache.blame, self.err = self.git_object:blame(lnum)
  if self.err then return self.err, nil end

  local blame = self._cache.blame

  if not blame then return { 'no blame found' }, nil end
  if blame:is_uncommitted() then return { 'Line is uncommitted' } end

  loop.free_textlock()
  local reponame = git_repo.discover()
  local log, log_err = git_log.get(reponame, blame.commit_hash)
  if log_err then return log_err end

  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  local lines_err, lines
  local is_deleted = false

  -- blame.filename will contain original name of the file if it was renamed.
  -- this is why we should use blame.filename filename passed as args.
  filename = blame.filename

  if not git_repo.has(reponame, filename, commit_hash) then
    is_deleted = true
    lines, lines_err = git_show.lines(reponame, filename, parent_hash)
  else
    lines, lines_err = git_show.lines(reponame, filename, commit_hash)
  end

  if lines_err then return lines_err end

  local hunks_err, hunks
  if is_deleted then
    hunks = git_hunks.custom(lines, { deleted = true })
  else
    hunks, hunks_err = git_hunks.list(reponame, filename, {
      parent = parent_hash,
      current = commit_hash,
    })
  end
  loop.free_textlock()

  if hunks_err then return hunks_err end

  self._cache.diff_dto = diff_service:generate(hunks, lines, self.shape, { is_deleted = is_deleted })

  return self.err
end

function Store:get_blame()
  return self.err, self._cache.blame
end

function Store:get_diff_dto()
  return nil, self._cache.diff_dto
end

function Store:get_filename()
  return nil, self.git_object:get_filename()
end

function Store:get_filetype()
  return nil, self.git_object:get_filetype()
end

return Store
