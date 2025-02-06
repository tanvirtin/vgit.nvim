local fs = require('vgit.core.fs')
local Diff = require('vgit.core.Diff')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local GitFile = require('vgit.git.GitFile')
local git_repo = require('vgit.libgit2.git_repo')
local git_show = require('vgit.libgit2.git_show')
local git_hunks = require('vgit.git.git_hunks')
local git_stager = require('vgit.git.git_stager')
local git_status = require('vgit.git.git_status')
local git_conflict = require('vgit.libgit2.git_conflict')

local Model = Object:extend()

function Model:constructor(opts)
  return {
    state = {
      id = nil,
      diffs = {},
      entries = nil,
      reponame = nil,
      list_entries = {},
      layout_type = opts.layout_type or 'unified',
    },
  }
end

function Model:reset()
  self.state = {
    id = nil,
    diffs = {},
    entries = nil,
    reponame = nil,
    list_entries = {},
    layout_type = self.state.layout_type,
  }
end

function Model:get_layout_type()
  return self.state.layout_type
end

function Model:partition_status(statuses)
  local changed_files = {}
  local staged_files = {}
  local unmerged_files = {}

  utils.list.each(statuses, function(status)
    if status:is_unmerged() then
      local id = utils.math.uuid()
      local data = { id = id, status = status, type = 'unmerged' }
      self.state.list_entries[id] = data
      table.insert(unmerged_files, data)
      -- If something is unmerged it cannot be untracked or staged
      return
    end

    if status:is_staged() then
      local id = utils.math.uuid()
      local data = { id = id, status = status, type = 'staged' }
      self.state.list_entries[id] = data
      table.insert(staged_files, data)
    end

    if status:is_unstaged() then
      local id = utils.math.uuid()
      local data = { id = id, status = status, type = 'unstaged' }
      self.state.list_entries[id] = data
      table.insert(changed_files, data)
    end
  end)

  return changed_files, staged_files, unmerged_files
end

function Model:fetch()
  self:reset()

  if not git_repo.exists() then return nil, { 'Project has no .git folder' } end

  loop.free_textlock()
  local reponame = git_repo.discover()
  local statuses, err = git_status.ls(reponame)
  if err then return nil, err end

  local changed_files, staged_files, unmerged_files = self:partition_status(statuses)

  local entries = {}
  if #unmerged_files ~= 0 then
    entries[#entries + 1] = {
      title = 'Merge Changes',
      entries = unmerged_files,
    }
  end
  if #staged_files ~= 0 then entries[#entries + 1] = {
    title = 'Staged Changes',
    entries = staged_files,
  } end
  if #changed_files ~= 0 then entries[#entries + 1] = {
    title = 'Changes',
    entries = changed_files,
  } end

  self.state.entries = entries
  self.state.reponame = reponame

  return self.state.entries
end

function Model:set_entry_id(id)
  self.state.id = id
end

function Model:get_entry(id)
  if id then self.state.id = id end
  return self.state.list_entries[self.state.id]
end

function Model:get_entries()
  return self.state.entries
end

function Model:get_filename()
  local entry, err = self:get_entry()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  return entry.status.filename
end

function Model:get_filepath()
  local reponame = self.state.reponame
  local filename = self:get_filename()
  if not filename then return nil, { 'entry not found' } end

  filename = fs.make_relative(reponame, filename)
  filename = string.format('%s/%s', reponame, filename)

  return filename
end

function Model:get_filetype()
  local entry, err = self:get_entry()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  return entry.status.filetype
end

function Model:conflict_status()
  return git_conflict.status(self.state.reponame)
end

function Model:get_lines(status, type)
  local filename = status.filename
  local reponame = self.state.reponame

  if status:has('D ') then return git_show.lines(reponame, filename, 'HEAD') end
  if type == 'staged' or status:has(' D') and not status:has_both('MD') then
    return git_show.lines(reponame, filename)
  end
  if status:has('MD') then return git_show.lines(reponame, filename, 'HEAD^1') end
  if type == 'unmerged' then return fs.read_file(self:get_filepath()) end

  return fs.read_file(self:get_filepath())
end

function Model:get_hunks(status, type, lines)
  local filename = status.filename
  local reponame = self.state.reponame

  if status:has_both('??') then return git_hunks.custom(lines, { untracked = true }) end
  if type == 'staged' then return git_hunks.list(reponame, { filename = filename, staged = true }) end
  if type == 'unstaged' then return git_hunks.list(reponame, { filename = filename }) end

  return {}
end

function Model:get_diff()
  local entry, err = self:get_entry()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  local id = entry.id
  local type = entry.type
  local status = entry.status
  if not status then return nil, { 'No status found in entry' } end

  local cache_key = string.format('%s-%s-%s', id, type, status.id)
  if self.state.diffs[cache_key] then return self.state.diffs[cache_key] end

  local lines, lines_err = self:get_lines(status, type)
  if lines_err then return nil, lines_err end

  local layout_type = self:get_layout_type()

  if type == 'unmerged' then
    local conflicts = git_conflict.parse(lines)
    local diff = Diff():generate(nil, lines, layout_type, { conflicts = conflicts })
    self.state.diffs[cache_key] = diff

    return diff
  end

  local hunks, hunks_err = self:get_hunks(status, type, lines)
  if hunks_err then return nil, hunks_err end

  loop.free_textlock()
  local is_deleted = status:has_either('DD') and not status:has_both('MD')
  local diff = Diff():generate(hunks, lines, layout_type, { is_deleted = is_deleted })
  self.state.diffs[cache_key] = diff

  return diff
end

function Model:stage_hunk(filename, hunk)
  local git_file = GitFile(filename)
  if not git_file:is_tracked() then return git_file:stage() end

  local file, err = git_file:status()
  if err then return nil, err end

  if file:has('D ') or file:has(' D') then return git_file:stage() end
  return git_file:stage_hunk(hunk)
end

function Model:unstage_hunk(filename, hunk)
  local git_file = GitFile(filename)
  if not git_file:is_tracked() then return git_file:unstage() end

  local file, err = git_file:status()
  if err then return nil, err end

  if file:has('D ') or file:has(' D') then return git_file:unstage(filename) end
  return git_file:unstage_hunk(hunk)
end

function Model:stage_file(filename)
  local reponame = git_repo.discover()
  return git_stager.stage(reponame, filename)
end

function Model:unstage_file(filename)
  local reponame = git_repo.discover()
  return git_stager.unstage(reponame, filename)
end

function Model:reset_file(filename)
  local reponame = git_repo.discover()
  if git_repo.has(reponame, filename) then return git_repo.reset(reponame, filename) end

  return git_repo.clean(reponame, filename)
end

function Model:stage_all()
  local reponame = git_repo.discover()
  return git_stager.stage(reponame)
end

function Model:unstage_all()
  local reponame = git_repo.discover()
  return git_stager.unstage(reponame)
end

function Model:reset_all()
  local reponame = git_repo.discover()
  local _, reset_err = git_repo.reset(reponame)
  if reset_err then return nil, reset_err end

  return git_repo.clean(reponame)
end

return Model
