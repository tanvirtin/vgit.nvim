local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local GitObject = require('vgit.git.GitObject')
local git_stager = require('vgit.git.git_stager')
local git_conflict = require('vgit.git.git_conflict')

local Model = Object:extend()

function Model:constructor(opts)
  return {
    git_object = nil,
    state = {
      diff = nil,
      is_hunk = opts.is_hunk,
      is_staged = opts.is_staged,
      layout_type = opts.layout_type or 'unified',
    },
  }
end

function Model:get_layout_type()
  return self.state.layout_type
end

function Model:is_hunk()
  return self.state.is_hunk
end

function Model:is_staged()
  return self.state.is_staged == true
end

function Model:toggle_staged()
  local is_staged = not self.state.is_staged
  self.state.is_staged = is_staged
  return is_staged
end

function Model:get_lines(filename, status)
  if self:is_staged() then return self.git_object:lines() end

  if status and status:is_unmerged() then
    if status:has_both('UD') then return self.git_object:lines(':2') end
    if status:has_both('DU') then return self.git_object:lines(':3') end
    local log, log_err = self.git_object:log({ rev = 'HEAD' })
    if log_err then return nil, log_err end
    if not log then return nil, { 'failed to find log at HEAD' } end
    return self.git_object:lines(log.commit_hash)
  end

  loop.free_textlock()
  return fs.read_file(filename)
end

function Model:get_hunks(status, lines)
  if self:is_staged() then return self.git_object:list_hunks({ staged = true }) end

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

function Model:fetch(filename)
  if not fs.exists(filename) then return nil, { 'Buffer has no diff associated with it' } end

  self.git_object = GitObject(filename)

  local has_conflict = self.git_object:has_conflict()
  if has_conflict and self:is_staged() then
    self.state.diff = nil
    return
  end

  local status = self.git_object:status()

  local lines, lines_err = self:get_lines(filename, status, opts)
  if lines_err then return nil, lines_err end

  local hunks, hunks_err = self:get_hunks(status, lines, opts)
  if hunks_err then return nil, hunks_err end

  self.state.diff = Diff():generate(hunks, lines, self:get_layout_type())

  return self.state.diff
end

function Model:get_diff()
  return self.state.diff
end

function Model:get_filename()
  return self.git_object:get_filename()
end

function Model:get_filetype()
  return self.git_object:get_filetype()
end

function Model:stage_hunk(filename, hunk)
  local git_object = GitObject(filename)
  if not git_object:is_tracked() then return git_object:stage() end

  return git_object:stage_hunk(hunk)
end

function Model:unstage_hunk(filename, hunk)
  local git_object = GitObject(filename)
  if not git_object:is_tracked() then return git_object:unstage() end

  return git_object:unstage_hunk(hunk)
end

function Model:stage_file(filename)
  local reponame = git_repo.discover()
  return git_stager.stage(reponame, filename)
end

function Model:unstage_file(filename)
  local reponame = git_repo.discover()
  return git_stager.unstage(reponame, filename)
end

function Model:reset_file(filename)
  local reponame = git_repo.discover()
  if git_repo.has(reponame, filename) then return git_repo.reset(reponame, filename) end

  return git_repo.clean(reponame, filename)
end

return Model
