local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local GitFile = require('vgit.git.GitFile')
local git_show = require('vgit.git.git_show')
local git_hunks = require('vgit.git.git_hunks')
local git_repo = require('vgit.libgit2.git_repo')

local Model = Object:extend()

function Model:constructor(opts)
  return {
    git_file = nil,
    state = {
      diff = nil,
      blame = nil,
      layout_type = opts.layout_type or 'unified',
    },
  }
end

function Model:reset()
  self.state = {
    diff = nil,
    blame = nil,
    layout_type = self.state.layout_type,
  }
end

function Model:get_layout_type()
  return self.state.layout_type
end

function Model:fetch(filename, lnum, opts)
  opts = opts or {}

  if not filename or filename == '' then return nil, { 'Buffer has no blame associated with it' } end

  self:reset()

  self.git_file = GitFile(filename)

  loop.free_textlock()
  local blame, err = self.git_file:blame(lnum)
  if err then return nil, err end
  if not blame then return nil, { 'no blame found' } end
  if blame:is_uncommitted() then return nil, { 'Line is uncommitted' } end

  loop.free_textlock()
  local reponame = git_repo.discover(filename)
  local log, log_err = git_log.get(reponame, blame.commit_hash)
  if log_err then return nil, log_err end
  if not log then return nil, { 'log not found' } end

  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  local lines_err, lines
  local is_deleted = false

  -- blame.filename will contain original name of the file if it was renamed.
  -- this is why we should use blame.filename filename passed as args.
  filename = blame.filename

  if not git_repo.has(reponame, filename, commit_hash) then
    local new_filename = self.git_file.filename
    if new_filename ~= filename and git_repo.has(reponame, new_filename, commit_hash) then
      lines, lines_err = git_show.lines(reponame, filename, commit_hash)
    else
      is_deleted = true
      lines, lines_err = git_show.lines(reponame, filename, parent_hash)
    end
  else
    lines, lines_err = git_show.lines(reponame, filename, commit_hash)
  end
  if lines_err then return nil, lines_err end

  local hunks_err, hunks
  if is_deleted then
    hunks = git_hunks.custom(lines, { deleted = true })
  else
    hunks, hunks_err = git_hunks.list(reponame, {
      filename = filename,
      parent = parent_hash,
      current = commit_hash,
    })
  end
  loop.free_textlock()
  if hunks_err then return nil, hunks_err end

  self.state.blame = blame
  self.state.diff = Diff():generate(hunks, lines, self:get_layout_type(), { is_deleted = is_deleted })

  return blame, err
end

function Model:get_blame()
  return self.state.blame
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

return Model
