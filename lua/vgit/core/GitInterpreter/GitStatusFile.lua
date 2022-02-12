local fs = require('vgit.core.fs')
local Diff = require('vgit.Diff')
local Object = require('vgit.core.Object')
local Git = require('vgit.cli.Git')

-- VGit git interpreter.
local git = Git:new()

local GitStatusFile = Object:extend()

-- file binder
-- Replicates itself as the file and adds lots of goodies.
-- lets make it become a file through something we made out of thin air. object becoming another object at runtime and stronger.
function GitStatusFile:new(file, layout_type)
  return setmetatable({
    file = file,
    layout_type = layout_type,
  }, GitStatusFile)
end

-- This is where we start doing caching magic

function GitStatusFile:is_untracked()
  return self.file:is_untracked()
end

function GitStatusFile:is_staged()
  return self.file:is_staged()
end

function GitStatusFile:is_unstaged()
  return self.file:is_unstaged()
end

function GitStatusFile:lines()
  local file = self.file
  local filename = file.filename
  local status = self.file.status
  local lines_err, lines
  if status:has('D ') then
    lines_err, lines = git:show(filename, 'HEAD')
  elseif status:has(' D') then
    lines_err, lines = git:show(git:tracked_filename(filename))
  else
    lines_err, lines = fs.read_file(filename)
  end
  return lines_err, lines
end

function GitStatusFile:hunks(lines)
  local file = self.file
  local filename = file.filename
  local status = file.status
  local hunks_err, hunks
  if status:has_both('??') then
    hunks = git:untracked_hunks(lines)
  elseif status:has_either('DD') then
    hunks = git:deleted_hunks(lines)
  else
    hunks_err, hunks = git:index_hunks(filename)
  end
  return hunks_err, hunks
end

-- Generating dto is powerful here.
function GitStatusFile:dto(lines, hunks)
  local file = self.file
  local status = file.status
  local dto
  if status:has_either('DD') then
    dto = Diff:new(hunks):call_deleted(lines, self.layout_type)
  else
    dto = Diff:new(hunks):call(lines, self.layout_type)
  end
  return nil, dto
end

return GitStatusFile
