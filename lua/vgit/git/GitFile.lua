local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_show = require('vgit.libgit2.git_show')
local git_repo = require('vgit.libgit2.git_repo')
local git_hunks = require('vgit.git.git_hunks')
local git_blame = require('vgit.git.git_blame')
local git_status = require('vgit.git.git_status')
local git_stager = require('vgit.git.git_stager')
local git_conflict = require('vgit.libgit2.git_conflict')

local GitFile = Object:extend()

function GitFile:constructor(filepath)
  local reponame = git_repo.discover(filepath)
  local filename = fs.make_relative(reponame, filepath)
  local filetype = fs.detect_filetype(filename)

  return {
    reponame = reponame,
    filepath = filepath,
    filename = filename,
    filetype = filetype,
    state = { hunks = nil },
  }
end

function GitFile:config()
  return git_repo.config(self.reponame)
end

function GitFile:get_filename()
  return self.filename
end

function GitFile:get_filetype()
  return self.filetype
end

function GitFile:get_hunks()
  return self.state.hunks
end

function GitFile:is_ignored()
  return git_repo.ignores(self.reponame, self.filename)
end

function GitFile:is_tracked()
  return git_repo.has(self.reponame, self.filename)
end

function GitFile:stage_hunk(hunk)
  return git_stager.stage_hunk(self.reponame, self.filename, hunk)
end

function GitFile:unstage_hunk(hunk)
  return git_stager.unstage_hunk(self.reponame, self.filename, hunk)
end

function GitFile:stage()
  return git_stager.stage(self.reponame, self.filename)
end

function GitFile:unstage()
  return git_stager.unstage(self.reponame, self.filename)
end

function GitFile:blame(lnum)
  return git_blame.get(self.reponame, self.filename, lnum)
end

function GitFile:blames()
  return git_blame.list(self.reponame, self.filename)
end

function GitFile:has_conflict()
  return git_conflict.has_conflict(self.reponame, self.filename)
end

function GitFile:conflicts(lines)
  return git_conflict.parse(lines)
end

function GitFile:conflict_status()
  return git_conflict.status(self.reponame)
end

function GitFile:log(opts)
  return git_log.get(self.reponame, opts.rev)
end

function GitFile:logs()
  return git_log.list(self.reponame, { filename = self.filename })
end

function GitFile:status()
  return git_status.ls(self.reponame, self.filename)
end

function GitFile:generate_status()
  local hunks = self.state.hunks or {}
  local status = { added = 0, changed = 0, removed = 0 }

  for _, h in ipairs(hunks) do
    local changed = math.min(h.stat.added, h.stat.removed)
    status.added = status.added + math.abs(h.stat.added - changed)
    status.removed = status.removed + math.abs(h.stat.removed - changed)
    status.changed = status.changed + changed
  end

  return status
end

function GitFile:lines(commit_hash)
  return git_show.lines(self.reponame, self.filename, commit_hash)
end

function GitFile:live_hunks(current_lines)
  if not git_repo.has(self.reponame, self.filename) then
    self.state.hunks = git_hunks.custom(current_lines, { untracked = true })
    return self.state.hunks
  end

  local original_lines, original_lines_err = self:lines()
  if original_lines_err then return nil, original_lines_err end

  self.state.hunks = git_hunks.live(original_lines, current_lines)

  return self.state.hunks
end

function GitFile:list_hunks(opts)
  if opts.deleted then
    local lines = opts.lines
    opts.lines = nil
    return git_hunks.custom(lines, opts)
  end
  if opts.untracked then
    local lines = opts.lines
    opts.lines = nil
    return git_hunks.custom(lines, opts)
  end

  opts.filename = self.filename
  return git_hunks.list(self.reponame, opts)
end

return GitFile
