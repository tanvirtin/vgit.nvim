local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.libgit2.git_repo')
local GitFile = require('vgit.git.GitFile')
local git_stager = require('vgit.git.git_stager')
local git_conflict = require('vgit.libgit2.git_conflict')

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

function Model:fetch(filename)
  if not fs.exists(filename) then return nil, { 'Buffer has no diff associated with it' } end

  self.git_file = GitFile(filename)

  local has_conflict = self.git_file:has_conflict()
  if has_conflict and self:is_staged() then
    self.state.diff = nil
    return
  end

  local status = self.git_file:status()

  local lines, lines_err = self:get_lines(filename)
  if lines_err then return nil, lines_err end

  local layout_type = self:get_layout_type()
  if status and status:is_unmerged() then
    local conflicts = git_conflict.parse(lines)
    self.state.diff = Diff():generate(nil, lines, layout_type, { conflicts = conflicts })
    return self.state.diff
  end
  local hunks, hunks_err = self:get_hunks(lines)
  if hunks_err then return nil, hunks_err end

  self.state.diff = Diff():generate(hunks, lines, layout_type)

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

function Model:stage_hunk(filename, hunk)
  local git_file = GitFile(filename)
  if not git_file:is_tracked() then return git_file:stage() end

  return git_file:stage_hunk(hunk)
end

function Model:unstage_hunk(filename, hunk)
  local git_file = GitFile(filename)
  if not git_file:is_tracked() then return git_file:unstage() end

  return git_file:unstage_hunk(hunk)
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
