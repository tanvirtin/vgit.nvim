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

function GitInterpreter:get_hunks_as_entries()
  local status_files_err, status_files = git:status()
  if status_files_err then
    return status_files_err
  end
  if #status_files == 0 then
    return { 'No files found' }
  end
  local entries = {}
  for i = 1, #status_files do
    local status_file = status_files[i]
    local git_status_file = GitStatusFile:new(status_file, self.layout_type)
    local hunks_err, hunks = git_status_file:get_hunks()
    if hunks_err then
      return hunks_err
    end
    local dto_err, dto = git_status_file:get_dto()
    if dto_err then
      return dto_err
    end
    local hunk_entries = {}
    for j = 1, #hunks do
      hunk_entries[#hunk_entries + 1] = {
        dto = dto,
        index = j,
        hunks = hunks,
        filename = status_file.filename,
        filetype = status_file.filetype,
      }
    end
    entries = utils.list.concat(entries, hunk_entries)
  end
  return nil, entries
end

function GitInterpreter:get_partitioned_files_as_entries()
  local status_files_err, status_files = git:status()
  if status_files_err then
    return status_files_err
  end
  if #status_files == 0 then
    return { 'No files found' }
  end
  local entries = utils.list.reduce(status_files, {
    changed_files = {},
    staged_files = {},
  }, function(acc, file)
    local changed_files = acc.changed_files
    local staged_files = acc.staged_files
    if file:is_untracked() then
      changed_files[#changed_files + 1] = file
    else
      if file:is_unstaged() then
        changed_files[#changed_files + 1] = file
      end
      if file:is_staged() then
        staged_files[#staged_files + 1] = file
      end
    end
    return acc
  end)
  return nil, entries.changed_files, entries.staged_files
end

return GitInterpreter
