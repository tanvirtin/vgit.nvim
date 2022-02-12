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

function GitInterpreter:get_hunks_entries()
  local status_files_err, status_files = git:status()
  if status_files_err then
    return status_files_err
  end
  if #status_files == 0 then
    return { 'No files found' }
  end
  local entries = {}
  for i = 1, #status_files do
    local hunk_entries_err, hunk_entries = GitStatusFile
      :new(status_files[i], self.layout_type)
      :get_hunk_entries()
    if hunk_entries_err then
      return hunk_entries_err
    end
    entries = utils.list.concat(entries, hunk_entries)
  end
  return nil, entries
end

return GitInterpreter
