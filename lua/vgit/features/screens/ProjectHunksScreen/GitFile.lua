local fs = require('vgit.core.fs')
local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')
local diff_service = require('vgit.services.diff')

local GitFile = Object:extend()

function GitFile:constructor(file, shape)
  return {
    git = Git(),
    file = file,
    shape = shape,
    _cache = {},
  }
end

function GitFile:get_lines()
  if self._cache['lines'] then
    return nil, self._cache['lines']
  end

  local file = self.file
  local filename = file.filename
  local status = self.file.status
  local lines_err, lines

  if status then
    if status:has('D ') then
      lines_err, lines = self.git:show(filename, 'HEAD')
    elseif status:has(' D') then
      lines_err, lines = self.git:show(self.git:tracked_filename(filename))
    else
      lines_err, lines = fs.read_file(filename)
    end
  else
    lines_err, lines = fs.read_file(filename)
  end

  self._cache['lines'] = lines

  return lines_err, lines
end

function GitFile:get_hunks()
  if self._cache['hunks'] then
    return nil, self._cache['hunks']
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
      hunks = self.git:untracked_hunks(lines)
    elseif status:has_either('DD') then
      hunks = self.git:deleted_hunks(lines)
    else
      hunks_err, hunks = self.git:index_hunks(filename)
    end
  elseif log then
    hunks_err, hunks = self.git:remote_hunks(filename, log.parent_hash, log.commit_hash)
  else
    hunks_err, hunks = self.git:index_hunks(filename)
  end

  self._cache['hunks'] = hunks

  return hunks_err, hunks
end

function GitFile:get_staged_hunks()
  if self._cache['hunks'] then
    return nil, self._cache['hunks']
  end

  local file = self.file
  local filename = file.filename
  local hunks_err, hunks

  if file:is_staged() then
    hunks_err, hunks = self.git:staged_hunks(filename)
  end

  self._cache['hunks'] = hunks

  return hunks_err, hunks
end

function GitFile:get_diff_dto()
  if self._cache['diff_dto'] then
    return nil, self._cache['diff_dto']
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
  local diff_dto = diff_service:generate(hunks, lines, self.shape, {
    is_deleted = status and status:has_either('DD'),
  })

  self._cache['diff_dto'] = diff_dto

  return nil, self._cache['diff_dto']
end

return GitFile
