local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git2.log')
local git_show = require('vgit.git.git2.show')
local git_repo = require('vgit.git.git2.repo')
local git_hunks = require('vgit.git.git2.hunks')
local git_blame = require('vgit.git.git2.blame')
local git_status = require('vgit.git.git2.status')
local git_stager = require('vgit.git.git2.stager')
local git_conflict = require('vgit.git.git2.conflict')

local GitObject = Object:extend()

function GitObject:constructor(filepath)
  local reponame = git_repo.discover(filepath)
  local filename = fs.relative_filename(filepath)
  local filetype = fs.detect_filetype(filename)

  return {
    hunks = nil,
    reponame = reponame,
    filepath = filepath,
    filename = filename,
    filetype = filetype,
  }
end

function GitObject:config()
  return git_repo.config()
end

function GitObject:get_filename()
  return self.filename
end

function GitObject:get_filetype()
  return self.filetype
end

function GitObject:is_ignored()
  return git_repo.ignores(self.reponame, self.filename)
end

function GitObject:is_tracked()
  return git_repo.has(self.reponame, self.filename)
end

function GitObject:stage_hunk(hunk)
  return git_stager.stage_hunk(self.reponame, self.filename, hunk)
end

function GitObject:unstage_hunk(hunk)
  return git_stager.unstage_hunk(self.reponame, self.filename, hunk)
end

function GitObject:stage()
  return git_stager.stage(self.reponame, self.filename)
end

function GitObject:unstage()
  return git_stager.unstage(self.reponame, self.filename)
end

function GitObject:lines(commit_hash)
  return git_show.lines(self.reponame, self.filename, commit_hash)
end

function GitObject:blame(lnum)
  return git_blame.get(self.reponame, self.filename, lnum)
end

function GitObject:blames()
  return git_blame.list(self.reponame, self.filename)
end

function GitObject:has_conflict()
  return git_conflict.has_conflict(self.reponame, self.filename)
end

function GitObject:parse_conflicts(lines)
  return git_conflict.parse(lines)
end

function GitObject:live_hunks(current_lines)
  if not git_repo.has(self.reponame, self.filename) then
    self.hunks = git_hunks.custom(current_lines, { untracked = true })
    return self.hunks
  end

  local original_lines, original_lines_err = self:lines()
  if original_lines_err then return nil, original_lines_err end

  self.hunks = git_hunks.live(original_lines, current_lines)
  return self.hunks
end

function GitObject:staged_hunks()
  return git_hunks.list(self.reponame, self.filename, { staged = true })
end

function GitObject:list_hunks(parent_hash, commit_hash)
  return git_hunks.list(self.reponame, self.filename, {
    parent = parent_hash,
    current = commit_hash
  })
end

function GitObject:logs()
  return git_log.list(self.reponame, self.filename)
end

function GitObject:status()
  return git_status.ls(self.reponame, self.filename)
end

function GitObject:generate_status()
  local hunks = self.hunks or {}
  local stats_dict = { added = 0, changed = 0, removed = 0 }

  for _, h in ipairs(hunks) do
    local changed = math.min(h.stat.added, h.stat.removed)
    stats_dict.added = stats_dict.added + math.abs(h.stat.added - changed)
    stats_dict.removed = stats_dict.removed + math.abs(h.stat.removed - changed)
    stats_dict.changed = stats_dict.changed + changed
  end

  return stats_dict
end

return GitObject
