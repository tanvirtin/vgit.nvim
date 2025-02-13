local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_show = require('vgit.git.git_show')
local git_hunks = require('vgit.git.git_hunks')
local git_repo = require('vgit.libgit2.git_repo')
local git_status = require('vgit.git.git_status')

local Model = Object:extend()

function Model:constructor(opts)
  return {
    shape = nil,
    state = {
      id = nil,
      diffs = {},
      statuses = {},
      entries = nil,
      layout_type = opts.layout_type or 'unified',
    },
  }
end

function Model:reset()
  self.state = {
    id = nil,
    diffs = {},
    statuses = {},
    entries = nil,
    layout_type = self.state.layout_type,
  }
end

function Model:get_layout_type()
  return self.state.layout_type
end

function Model:fetch(commits, opts)
  opts = opts or {}

  self:reset()

  if not commits or #commits == 0 then return nil, { 'No commits specified' } end
  if not git_repo.exists() then return nil, { 'Project has no .git folder' } end

  local entries = {}
  local reponame = git_repo.discover()

  for i = 1, #commits do
    local commit = commits[i]
    local log, err = git_log.get(reponame, commit)
    if err then return nil, err end
    if not log then return nil, { 'No log found for commit' } end

    loop.free_textlock()
    local statuses, status_err = git_status.tree(reponame, {
      commit_hash = log.commit_hash,
      parent_hash = log.parent_hash,
    })
    if status_err then return nil, status_err end

    entries[#entries + 1] = {
      title = commit:sub(1, 7) .. ' (' .. log.author_name .. ')' .. ': ' .. log.summary,
      entries = utils.list.map(statuses, function(status)
        local id = utils.math.uuid()
        local entry = {
          id = id,
          log = log,
          status = status,
        }
        self.state.statuses[id] = entry

        return entry
      end),
    }
  end

  self.state.entries = entries

  return entries
end

function Model:get_entries()
  return self.state.entries
end

function Model:set_entry_id(id)
  self.state.id = id
end

function Model:get_entry(id)
  if id then self.state.id = id end

  local entry = self.state.statuses[self.state.id]
  if not entry then return nil, { 'Item not found' } end

  return entry
end

function Model:get_diff()
  local entry, err = self:get_entry()
  if err then return nil, err end
  if not entry then return nil, { 'no data found' } end

  local status = entry.status
  if not status then return nil, { 'No file found in item' } end

  local log = entry.log
  if not log then return nil, { 'No log found in item' } end

  local id = status.id
  local filename = status.filename
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  if self.state.diffs[id] then return self.state.diffs[id] end

  local is_deleted = status:has_either('DD')
  local reponame = git_repo.discover()
  local lines_err, lines
  if is_deleted then
    lines, lines_err = git_show.lines(reponame, filename, parent_hash)
  else
    lines, lines_err = git_show.lines(reponame, filename, commit_hash)
  end
  loop.free_textlock()
  if lines_err then return nil, lines_err end

  local hunks, hunks_err = git_hunks.list(reponame, {
    filename = filename,
    parent = parent_hash,
    current = commit_hash,
  })
  loop.free_textlock()
  if hunks_err then return nil, hunks_err end

  local layout_type = self:get_layout_type()
  local diff = Diff():generate(hunks, lines, layout_type, { is_deleted = is_deleted })

  self.state.diffs[id] = diff

  return diff
end

function Model:get_filename()
  local entry, err = self:get_entry()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  return entry.status.filename
end

function Model:get_filetype()
  local entry, err = self:get_entry()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  return entry.status.filetype
end

function Model:get_parent_commit()
  local entry, err = self:get_entry()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  local status = entry.status
  if not status then return nil, { 'No status found in item' } end

  local log = entry.log
  if not log then return nil, { 'No log found in item' } end

  return log.parent_hash
end

return Model
