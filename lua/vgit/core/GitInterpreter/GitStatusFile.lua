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
    _cache = {},
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

function GitStatusFile:get_lines()
  if self._cache['lines'] then
    return nil, self._cache['lines']
  end
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
  self._cache['lines'] = lines
  return lines_err, lines
end

function GitStatusFile:get_hunks()
  if self._cache['hunks'] then
    return nil, self._cache['hunks']
  end
  local lines_err, lines = self:get_lines()
  if lines_err then
    return lines_err
  end
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
  self._cache['hunks'] = hunks
  return hunks_err, hunks
end

-- Generating dto is powerful here.
function GitStatusFile:get_dto()
  if self._cache['dto'] then
    return nil, self._cache['dto']
  end
  local lines_err, lines = self:get_lines()
  if lines_err then
    return lines_err
  end
  local hunks_err, hunks = self:get_hunks()
  if hunks_err then
    return hunks_err
  end
  local file = self.file
  local status = file.status
  local dto
  if status:has_either('DD') then
    dto = Diff:new(hunks):call_deleted(lines, self.layout_type)
  else
    dto = Diff:new(hunks):call(lines, self.layout_type)
  end
  self._cache['dto'] = dto
  return nil, dto
end

function GitStatusFile:hunk_entries()
  if self._cache['entries'] then
    return nil, self._cache['entries']
  end
  local hunks_err, hunks = self:get_hunks()
  if hunks_err then
    return hunks_err
  end
  local dto_err, dto = self:get_dto()
  if dto_err then
    return dto_err
  end
  local file = self.file
  local entries = {}
  for j = 1, #hunks do
    entries[#entries + 1] = {
      -- data reveals it's own position in the array.
      dto = dto,
      index = j,
      hunks = hunks,
      filename = file.filename,
      filetype = file.filetype,
    }
  end
  self._cache['entries'] = entries
  return nil, entries
end

return GitStatusFile
