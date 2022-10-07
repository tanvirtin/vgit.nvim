local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local git_service = require('vgit.services.git')

local ProjectHunksQuickfix = Object:extend()

function ProjectHunksQuickfix:constructor() return { name = 'Project Hunks List' } end

function ProjectHunksQuickfix:fetch()
  local entries = {}
  local git_repository = git_service:get_repository()
  local status_files_err, status_files = git_repository:status()

  loop.await()
  if status_files_err then
    return console.debug.error(status_files_err)
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
        hunks = git_repository:untracked_hunks(lines)
      else
        console.debug.error(show_err)
      end
    else
      hunks_err, hunks = git_repository:index_hunks(filename)
    end

    loop.await()
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
      console.debug.error(hunks_err)
    end
  end

  return entries
end

function ProjectHunksQuickfix:show()
  local entries = self:fetch()

  if #entries == 0 then
    console.log('No changes found in working directory')

    return entries
  end

  vim.fn.setqflist(entries, 'r')
  vim.cmd('copen')
end

return ProjectHunksQuickfix
