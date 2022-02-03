local fs = require('vgit.core.fs')
local console = require('vgit.core.console')
local loop = require('vgit.core.loop')
local Git = require('vgit.cli.Git')
local Feature = require('vgit.Feature')

local ProjectHunksList = Feature:extend()

function ProjectHunksList:new(versioning)
  return setmetatable({
    name = 'Project Hunks List',
    versioning = versioning,
    git = Git:new(),
  }, ProjectHunksList)
end

function ProjectHunksList:fetch()
  local git = self.git
  local entries = {}
  local status_files_err, status_files = git:status()
  loop.await_fast_event()
  if status_files_err then
    return console.debug(status_files_err, debug.traceback())
  end
  if #status_files == 0 then
    return entries
  end
  for i = 1, #status_files do
    local file = status_files[i]
    local filename = file.filename
    local status = file.status
    local hunks_err, hunks
    if status:has_both('??') then
      local show_err, lines = fs.read_file(filename)
      if not show_err then
        hunks = git:untracked_hunks(lines)
      else
        console.debug(show_err, debug.traceback())
      end
    else
      hunks_err, hunks = git:index_hunks(filename)
    end
    loop.await_fast_event()
    if not hunks_err then
      for j = 1, #hunks do
        local hunk = hunks[j]
        entries[#entries + 1] = {
          text = string.format(
            'lines: [%s..%s] +%s -%s',
            hunk.top,
            hunk.bot,
            hunk.stat.added,
            hunk.stat.removed,
            hunk.stat.modified
          ),
          filename = filename,
          lnum = hunk.top,
          col = 0,
        }
      end
    else
      console.debug(hunks_err, debug.traceback())
    end
  end
  return entries
end

function ProjectHunksList:show_as_quickfix(entries)
  if #entries == 0 then
    console.log('No changes found in working directory')
    return entries
  end
  vim.fn.setqflist(entries, 'r')
  vim.cmd('copen')
end

return ProjectHunksList
