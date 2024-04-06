local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local Hunk = require('vgit.git.cli.models.Hunk')
local git_log = require('vgit.git.git2.log')
local git_show = require('vgit.git.git2.show')
local git_repo = require('vgit.git.git2.repo')
local git_hunks = require('vgit.git.git2.hunks')
local git_blame = require('vgit.git.git2.blame')
local git_status = require('vgit.git.git2.status')
local git_stager = require('vgit.git.git2.stager')

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

function GitObject:live_hunks(current_lines)
  local original_lines, original_lines_err = self:lines()
  if original_lines_err then return original_lines_err end

  local o_lines_str = ''
  local c_lines_str = ''
  local num_lines = math.max(#original_lines, #current_lines)

  for i = 1, num_lines do
    local o_line = original_lines[i]
    local c_line = current_lines[i]

    if o_line then
      o_lines_str = o_lines_str .. original_lines[i] .. '\n'
    end
    if c_line then
      c_lines_str = c_lines_str .. current_lines[i] .. '\n'
    end
  end

  local hunks = {}

  loop.free_textlock()
  vim.diff(o_lines_str, c_lines_str, {
    on_hunk = function(start_o, count_o, start_c, count_c)
      local hunk = Hunk({ { start_o, count_o }, { start_c, count_c } })

      hunks[#hunks + 1] = hunk

      if count_o > 0 then
        for i = start_o, start_o + count_o - 1 do
          hunk.diff[#hunk.diff + 1] = '-' .. (original_lines[i] or '')
          hunk.stat.removed = hunk.stat.removed + 1
        end
      end

      if count_c > 0 then
        for i = start_c, start_c + count_c - 1 do
          hunk.diff[#hunk.diff + 1] = '+' .. (current_lines[i] or '')
          hunk.stat.added = hunk.stat.added + 1
        end
      end
    end,
    algorithm = 'myers',
  })

  self.hunks = hunks

  return nil, hunks
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
