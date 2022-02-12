local Object = require('vgit.core.Object')
local utils = require('vgit.core.utils')
local Git = require('vgit.cli.Git')
local Diff = require('vgit.Diff')
local fs = require('vgit.core.fs')

-- VGit git interpreter.
local git = Git:new()

local GitInterpreter = Object:extend()

-- I can implement my own caching solution here. This is my apollo.
function GitInterpreter:new(layout_type)
  return setmetatable({
    -- Screen layout information.
    layout_type = layout_type,
  }, GitInterpreter)
end

function GitInterpreter:get_status_file_lines(status_file)
  local filename = status_file.filename
  local status = status_file.status
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

function GitInterpreter:get_status_file_hunks(status_file, lines)
  local filename = status_file.filename
  local status = status_file.status
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

function GitInterpreter:get_status_file_dto(status_file, lines, hunks)
  local status = status_file.status
  local dto
  if status:has_either('DD') then
    dto = Diff:new(hunks):call_deleted(lines, self.layout_type)
  else
    dto = Diff:new(hunks):call(lines, self.layout_type)
  end
  return nil, dto
end

function GitInterpreter:get_status_file_hunk_entries(status_file)
  local lines_err, lines = self:get_status_file_lines(status_file)
  if lines_err then
    return lines_err
  end
  local hunks_err, hunks = self:get_status_file_hunks(status_file, lines)
  if hunks_err then
    return hunks_err
  end
  local dto_err, dto = self:get_status_file_dto(status_file, lines, hunks)
  if dto_err then
    return dto_err
  end
  local entries = {}
  for j = 1, #hunks do
    entries[#entries + 1] = {
      -- data reveals it's own position in the array.
      dto = dto,
      index = j,
      hunks = hunks,
      filename = status_file.filename,
      filetype = status_file.filetype,
    }
  end
  return nil, entries
end

function GitInterpreter:project_hunks_entries()
  local status_files_err, status_files = git:status()
  if status_files_err then
    return status_files_err
  end
  if #status_files == 0 then
    return { 'No files found' }
  end
  local entries = {}
  for i = 1, #status_files do
    local hunk_entries_err, hunk_entries = self:get_status_file_hunk_entries(
      status_files[i]
    )
    if hunk_entries_err then
      return hunk_entries_err
    end
    entries = utils.list.concat(entries, hunk_entries)
  end
  return nil, entries
end

return GitInterpreter
