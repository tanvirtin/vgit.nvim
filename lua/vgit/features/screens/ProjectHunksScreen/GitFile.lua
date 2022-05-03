local fs = require('vgit.core.fs')
local Diff = require('vgit.git.Diff')
local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')

local git = Git()

local GitFile = Object:extend()

function GitFile:constructor(file, shape)
  return {
    file = file,
    shape = shape,
    _diff_dto_cache = {},
  }
end

function GitFile:get_lines()
  if self._diff_dto_cache['lines'] then
    return nil, self._diff_dto_cache['lines']
  end

  local file = self.file
  local filename = file.filename
  local status = self.file.status
  local lines_err, lines

  if status then
    if status:has('D ') then
      lines_err, lines = git:show(filename, 'HEAD')
    elseif status:has(' D') then
      lines_err, lines = git:show(git:tracked_filename(filename))
    else
      lines_err, lines = fs.read_file(filename)
    end
  else
    lines_err, lines = fs.read_file(filename)
  end

  self._diff_dto_cache['lines'] = lines

  return lines_err, lines
end

function GitFile:get_hunks()
  if self._diff_dto_cache['hunks'] then
    return nil, self._diff_dto_cache['hunks']
  end

  local lines_err, lines = self:get_lines()
  if lines_err then
    return lines_err
  end

  local file = self.file
  local filename = file.filename
  local status = file.status
  local log = file.log
  local hunks_err, hunks

  if status then
    if status:has_both('??') then
      hunks = git:untracked_hunks(lines)
    elseif status:has_either('DD') then
      hunks = git:deleted_hunks(lines)
    else
      hunks_err, hunks = git:index_hunks(filename)
    end
  elseif log then
    hunks = git:remote_hunks(filename, log.parent_hash, log.commit_hash)
  else
    hunks_err, hunks = git:index_hunks(filename)
  end

  self._diff_dto_cache['hunks'] = hunks

  return hunks_err, hunks
end

function GitFile:get_diff_dto()
  if self._diff_dto_cache['diff_dto'] then
    return nil, self._diff_dto_cache['diff_dto']
  end

  local lines_err, lines = self:get_lines()

  if lines_err then
    return lines_err
  end

  local hunks_err, hunks = self:get_hunks()

  if hunks_err then
    return hunks_err
  end

  local file = self.file
  local status = file.status
  local diff_dto

  if status and status:has_either('DD') then
    diff_dto = Diff(hunks):call_deleted(lines, self.shape)
  else
    diff_dto = Diff(hunks):call(lines, self.shape)
  end

  self._diff_dto_cache['diff_dto'] = diff_dto

  return nil, self._diff_dto_cache['diff_dto']
end

return GitFile
