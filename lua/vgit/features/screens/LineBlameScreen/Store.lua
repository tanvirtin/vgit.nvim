local loop = require('vgit.core.loop')
local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')
local diff_service = require('vgit.services.diff')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    shape = nil,
    git = Git(),
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

  if not filename or filename == '' then
    return { 'Buffer has no blame associated with it' }, nil
  end

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)

  loop.await()
  self.err, self._cache.blame = self.git_object:blame_line(lnum)
  loop.await()

  if self.err then
    return self.err
  end

  local blame = self._cache.blame

  if blame:is_uncommitted() then
    return { 'Line is uncommitted' }
  end

  local log_err, log = self.git:log(blame.commit_hash)

  if log_err then
    return log_err
  end

  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  local lines_err, lines
  local is_deleted = false

  -- blame.filename will contain original name of the file if it was renamed.
  -- this is why we should use blame.filename filename passed as args.
  filename = blame.filename

  loop.await()
  if not self.git:is_in_remote(filename, commit_hash) then
    is_deleted = true
    lines_err, lines = self.git:show(filename, parent_hash)
  else
    lines_err, lines = self.git:show(filename, commit_hash)
  end

  if lines_err then
    return lines_err
  end

  local hunks_err, hunks
  if is_deleted then
    hunks = self.git:deleted_hunks(lines)
  else
    hunks_err, hunks = self.git:remote_hunks(filename, parent_hash, commit_hash)
  end
  loop.await()

  if hunks_err then
    return hunks_err
  end

  self._cache.diff_dto = diff_service:generate(hunks, lines, self.shape, { is_deleted = is_deleted })

  return self.err
end

function Store:get_blame() return self.err, self._cache.blame end

function Store:get_diff_dto() return nil, self._cache.diff_dto end

function Store:get_filename() return nil, self.git_object:get_filename() end

function Store:get_filetype() return nil, self.git_object:get_filetype() end

return Store
