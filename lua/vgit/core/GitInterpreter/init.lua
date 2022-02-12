local Object = require('vgit.core.Object')
local GitStatusFile = require('vgit.core.GitInterpreter.GitStatusFile')
local utils = require('vgit.core.utils')
local Git = require('vgit.cli.Git')

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

-- Create GitStatusFile as an interpretor for git commands.
function GitInterpreter:get_status_file_hunk_entries(status_file)
  local git_status_file = GitStatusFile:new(status_file, self.layout_type)
  local lines_err, lines = git_status_file:lines()
  if lines_err then
    return lines_err
  end
  local hunks_err, hunks = git_status_file:hunks(lines)
  if hunks_err then
    return hunks_err
  end
  local dto_err, dto = git_status_file:dto(lines, hunks)
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
