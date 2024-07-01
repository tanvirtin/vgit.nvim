local fs = require('vgit.core.fs')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')
local git_conflict = require('vgit.git.git_conflict')

local Store = Object:extend()

function Store:constructor()
  return {
    shape = nil,
    git_object = nil,
    state = { diff = nil },
  }
end

function Store:reset()
  self.state = { diff = nil }
end

function Store:get_lines(filename, status, opts)
  if opts.is_staged then return self.git_object:lines() end

  if status and status:is_unmerged() then
    if status:has_both('UD') then return self.git_object:lines(':2') end
    if status:has_both('DU') then return self.git_object:lines(':3') end
    local log, log_err = self.git_object:log({ rev = 'HEAD' })
    if log_err then return nil, log_err end
    if not log then return nil, { 'failed to find log at HEAD' } end
    return self.git_object:lines(log.commit_hash)
  end

  return fs.read_file(filename)
end

function Store:get_hunks(status, lines, opts)
  if opts.is_staged then return self.git_object:list_hunks({ staged = true }) end

  if status and status:is_unmerged() then
    if status:has_both('UD') then return self.git_object:list_hunks({ lines = lines, deleted = true }) end
    if status:has_both('DU') then return self.git_object:list_hunks({ lines = lines, untracked = true }) end
    if status:has_either('DD') then return self.git_object:list_hunks({ lines = lines, deleted = true }) end
    local head_log, head_log_err = self.git_object:log({ rev = 'HEAD' })
    if head_log_err then return nil, head_log_err end
    if not head_log then return nil, { 'failed to find head log' } end
    local conflict_type, conflict_type_err = git_conflict.status(self.git_object.reponame)
    if conflict_type_err then return nil, conflict_type_err end
    local merge_log, merge_log_err = self.git_object:log({ rev = conflict_type })
    if not merge_log then return nil, { 'failed to find merge log' } end
    if merge_log_err then return nil, merge_log_err end
    return self.git_object:list_hunks({ parent = head_log.commit_hash, current = merge_log.commit_hash })
  end

  return self.git_object:live_hunks(lines)
end

function Store:fetch(shape, filename, opts)
  opts = opts or {}

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)

  local has_conflict = self.git_object:has_conflict()
  if has_conflict and opts.is_staged then
    self.state.diff = nil
    return
  end

  local status = self.git_object:status()

  local lines, lines_err = self:get_lines(filename, status, opts)
  if lines_err then return nil, lines_err end

  local hunks, hunks_err = self:get_hunks(status, lines, opts)
  if hunks_err then return nil, hunks_err end

  self.state.diff = Diff():generate(hunks, lines, self.shape)

  return self.state.diff
end

function Store:get_diff()
  return self.state.diff
end

function Store:get_filename()
  return self.git_object:get_filename()
end

function Store:get_filetype()
  return self.git_object:get_filetype()
end

return Store
