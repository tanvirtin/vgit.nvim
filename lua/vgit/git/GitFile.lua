local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_hunks = require('vgit.git.git_hunks')
local git_blame = require('vgit.git.git_blame')
local git_repo = require('vgit.libgit2.git_repo')
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
  local result, err = git_repo.ignores(self.reponame, self.filename)
  if err then return nil, err end
  return result, nil
end

function GitFile:is_tracked()
  local result, err = git_repo.has(self.reponame, self.filename)
  if err then return nil, err end
  return result, nil
end

function GitFile:stage_hunk(hunk)
  local result, err = git_stager.stage_hunk(self.reponame, self.filename, hunk)
  if err then return nil, err end
  return result, nil
end

function GitFile:unstage_hunk(hunk)
  local result, err = git_stager.unstage_hunk(self.reponame, self.filename, hunk)
  if err then return nil, err end
  return result, nil
end

function GitFile:reset_hunk(hunk)
  return git_stager.reset_hunk(self.reponame, self.filename, hunk)
end

function GitFile:stage()
  local result, err = git_stager.stage(self.reponame, self.filename)
  if err then return nil, err end
  return result, nil
end

function GitFile:unstage()
  local result, err = git_stager.unstage(self.reponame, self.filename)
  if err then return nil, err end
  return result, nil
end

function GitFile:blame(lnum)
  local result, err = git_blame.get(self.reponame, self.filename, lnum)
  if err then return nil, err end
  return result, nil
end

function GitFile:blames()
  local result, err = git_blame.list(self.reponame, self.filename)
  if err then return nil, err end
  return result, nil
end

function GitFile:has_conflict()
  local result, err = git_conflict.has_conflict(self.reponame, self.filename)
  if err then return nil, err end
  return result, nil
end

function GitFile:conflicts(lines)
  local result, err = git_conflict.parse(lines)
  if err then return nil, err end
  return result, nil
end

function GitFile:conflict_status()
  local result, err = git_conflict.status(self.reponame)
  if err then return nil, err end
  return result, nil
end

function GitFile:log(opts)
  local result, err = git_log.get(self.reponame, opts.rev)
  if err then return nil, err end
  return result, nil
end

function GitFile:logs()
  local result, err = git_log.list(self.reponame, { filename = self.filename })
  if err then return nil, err end
  return result, nil
end

function GitFile:status()
  local result, err = git_status.ls(self.reponame, self.filename)
  if err then return nil, err end
  return result, nil
end

function GitFile:generate_status()
  local hunks = self.state.hunks or {}
  local status = { added = 0, changed = 0, removed = 0 }
  local math_min = math.min
  local math_abs = math.abs

  for _, h in ipairs(hunks) do
    local h_added = h.stat.added
    local h_removed = h.stat.removed
    local changed = math_min(h_added, h_removed)
    status.added = status.added + math_abs(h_added - changed)
    status.removed = status.removed + math_abs(h_removed - changed)
    status.changed = status.changed + changed
  end

  return status
end

function GitFile:lines(commit_hash)
  local GitBlob = require('vgit.git.GitBlob')
  local blob = GitBlob(self.reponame, self.filename, commit_hash)
  return blob:lines()
end

function GitFile:live_hunks(current_lines)
  local has_file, has_err = git_repo.has(self.reponame, self.filename)
  if has_err then return nil, has_err end

  if not has_file then
    self.state.hunks = git_hunks.custom(current_lines, { untracked = true })
    return self.state.hunks, nil
  end

  local GitBlob = require('vgit.git.GitBlob')
  local blob = GitBlob(self.reponame, self.filename, 'index')
  local original_lines, err = blob:lines()
  if err then return nil, err end

  local hunks, hunks_err = git_hunks.live(self.reponame, original_lines, current_lines)
  if hunks_err then return nil, hunks_err end

  self.state.hunks = hunks

  return self.state.hunks, nil
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
