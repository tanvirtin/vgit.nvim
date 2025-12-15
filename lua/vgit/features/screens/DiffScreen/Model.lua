local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local GitFile = require('vgit.git.GitFile')
local git_stager = require('vgit.git.git_stager')
local git_conflict = require('vgit.git.git_conflict')

local Model = Object:extend()

function Model:constructor(opts)
  return {
    git_file = nil,
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

function Model:get_lines(filename)
  if self:is_staged() then return self.git_file:lines() end
  loop.free_textlock()
  return fs.read_file(filename)
end

function Model:get_hunks(lines)
  if self:is_staged() then return self.git_file:list_hunks({ staged = true }) end
  return self.git_file:live_hunks(lines)
end

-- Lightweight refresh that skips redundant checks (conflict, status).
-- Use after staging/unstaging when we know the file state hasn't fundamentally changed.
function Model:refresh_hunks(filename)
  local lines, lines_err = self:get_lines(filename)
  if lines_err then return nil, lines_err end

  local hunks, hunks_err = self:get_hunks(lines)
  if hunks_err then return nil, hunks_err end

  self.state.diff = Diff():generate(hunks, lines, self:get_layout_type())
  return self.state.diff
end

function Model:fetch(filename)
  if not fs.exists(filename) then return nil, { 'Buffer has no diff associated with it' } end

  self.git_file = GitFile(filename)

  -- Fast filesystem check: are we in a merge/rebase/cherry-pick state?
  -- Only run expensive per-file conflict checks if so.
  local conflict_status = git_conflict.status(self.git_file.reponame)
  if conflict_status then
    local has_conflict = self.git_file:has_conflict()
    if has_conflict and self:is_staged() then
      self.state.diff = nil
      return
    end

    local status = self.git_file:status()
    if status and status:is_unmerged() then
      local lines, lines_err = self:get_lines(filename)
      if lines_err then return nil, lines_err end

      local layout_type = self:get_layout_type()
      local conflicts = git_conflict.parse(lines)
      self.state.diff = Diff():generate(nil, lines, layout_type, { conflicts = conflicts })
      return self.state.diff
    end
  end

  local lines, lines_err = self:get_lines(filename)
  if lines_err then return nil, lines_err end

  local hunks, hunks_err = self:get_hunks(lines)
  if hunks_err then return nil, hunks_err end

  self.state.diff = Diff():generate(hunks, lines, self:get_layout_type())
  return self.state.diff
end

function Model:get_diff()
  return self.state.diff
end

function Model:get_filename()
  return self.git_file:get_filename()
end

function Model:get_filetype()
  return self.git_file:get_filetype()
end

function Model:stage_hunk(hunk)
  if not self.git_file:is_tracked() then return self.git_file:stage() end

  return self.git_file:stage_hunk(hunk)
end

function Model:unstage_hunk(hunk)
  if not self.git_file:is_tracked() then return self.git_file:unstage() end

  return self.git_file:unstage_hunk(hunk)
end

function Model:reset_hunk(hunk)
  return self.git_file:reset_hunk(hunk)
end

function Model:stage_file()
  return self.git_file:stage()
end

function Model:unstage_file()
  return self.git_file:unstage()
end

function Model:reset_file()
  local reponame = self.git_file.reponame
  local filename = self.git_file.filename
  if git_repo.has(reponame, filename) then return git_repo.reset(reponame, filename) end

  return git_repo.clean(reponame, filename)
end

return Model
