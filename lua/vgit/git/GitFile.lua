local fs = require('vgit.core.fs')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local git_show = require('vgit.git.git_show')
local git_hunks = require('vgit.git.git_hunks')
local git_status = require('vgit.git.git_status')

local GitFile = Object:extend()

function GitFile:constructor(reponame, filename, revision)
  if not reponame then error('reponame is required') end
  if not filename then error('filename is required') end
  if not revision then error('revision is required') end

  return {
    reponame = reponame,
    filename = filename,
    revision = revision,
    state = {
      status = nil,
      is_tracked = nil
    }
  }
end

function GitFile:is_tracked()
  if self.state.is_tracked then return self.state.is_tracked end
  local is_tracked, err = git_repo.has(self.reponame, self.filename)
  if err then return nil, err end

  self.state.is_tracked = is_tracked

  return is_tracked, err
end

function GitFile:status()
  if self.state.status then return self.state.status end

  local status, err = git_status.get(
    self.reponame,
    self.filename,
    self.revision ~= 'INDEX' and self.revision or nil
  )
  if err then return nil, err end
  self.state.status = status

  return status
end

function GitFile:live_hunks(current_lines)
  if not current_lines then return nil, { 'lines is required' } end
  if self.revision ~= 'INDEX' then return nil, { 'invalid revision for live hunk' } end
  if not self:is_tracked() then return git_hunks.custom(current_lines, { untracked = true }) end

  local original_lines, err = fs.read_file(self.filename)
  if err then return nil, err end

  return git_hunks.live(original_lines, current_lines)
end

function GitFile:diff(shape)
  local reponame = self.reponame
  local filename = self.filename

  if self.revision == 'INDEX' then
    local status, err = self:status()
    if err then return nil, err end
    if not status then return nil, { 'status not found' } end

    local lines = nil
    local hunks = nil

    if status:unmerged() then
      if status:has_both('UD') then
        lines, err = git_show.lines(reponame, filename, ':2')
        if err then return nil, err end
        hunks, err = git_hunks.list_hunks(filename, { lines = lines, deleted = true })
        if err then return nil, err end
      elseif status:has_both('DU') then
        lines, err = git_show.lines(reponame, filename, ':3')
        if err then return nil, err end
        hunks, err = git_hunks.list_hunks(filename, { lines = lines, untracked = true })
        if err then return nil, err end
      else
        lines, err = git_show.lines(reponame, filename, 'HEAD')
        if err then return nil, err end
        if status:has_either('DD') then
          hunks, err = git_hunks.list_hunks(filename, { lines = lines, deleted = true })
        else
          hunks, err = git_show.lines(reponame, filename, 'HEAD')
        end
        if err then return nil, err end
      end
    else
      local path = string.format('%s%s%s', self.reponame, fs.sep, self.filename)
      lines, err = fs.read_file(path)
      if err then return nil, err end
      hunks, err = self:live_hunks(lines)
      if err then return nil, err end
    end

    return Diff():generate(hunks, lines, shape)
  end
end

return GitFile
