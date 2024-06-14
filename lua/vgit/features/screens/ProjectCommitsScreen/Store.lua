local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_repo = require('vgit.git.git_repo')
local git_show = require('vgit.git.git_show')
local git_hunks = require('vgit.git.git_hunks')
local git_status = require('vgit.git.git_status')

local Store = Object:extend()

function Store:constructor()
  return {
    id = nil,
    err = nil,
    data = nil,
    shape = nil,
    state = {
      lnum = 1,
      commits = {},
      list_entry_cache = {},
    },
  }
end

function Store:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self.state = {
    lnum = 1,
    commits = {},
    list_entry_cache = {},
  }
end

function Store:fetch(shape, commits, opts)
  opts = opts or {}

  self:reset()

  if not commits or #commits == 0 then
    self.err = { 'No commits specified' }
    return nil, self.err
  end

  self.state = {
    lnum = 1,
    commits = {},
    list_entry_cache = {},
  }

  if not git_repo.exists() then
    self.err = { 'Project has no .git folder' }
    return nil, self.err
  end

  self.shape = shape
  local data = {}

  for i = 1, #commits do
    local commit = commits[i]
    loop.free_textlock()
    local reponame = git_repo.discover()
    local log, err = git_log.get(reponame, commit)
    if err then
      self.err = err
      return nil, err
    end
    if not log then
      self.err = { 'No log found for commit' }
      return nil, self.err
    end

    -- We will use the parent_hash and the commit_hash inside
    -- the log object to list all the files associated with the log.
    loop.free_textlock()
    local statuses, status_err = git_status.tree(reponame, {
      commit_hash = log.commit_hash,
      parent_hash = log.parent_hash,
    })
    if status_err then
      self.err = status_err
      return nil, status_err
    end

    data[commit] = utils.list.map(statuses, function(status)
      -- Log contains the metadata about parent_hash and commit_hash
      -- File contains the name of the file in that particular working tree.
      -- Using commit_hash, parent_hash and the name of the file we can easily get the lines
      -- and hunks to recreate the diffs by feeding this info into our algorithm.
      local datum = {
        id = utils.math.uuid(),
        commit = commit,
        log = log,
        file = status,
      }
      self.state.commits[datum.id] = datum

      return datum
    end)
  end

  self.data = data

  return self.data
end

function Store:set_id(id)
  self.id = id
end

function Store:get_all()
  return self.data, self.err
end

function Store:get(id)
  if self.err then return nil, self.err end
  if id then self.id = id end

  local datum = self.state.commits[self.id]
  if not datum then return nil, { 'Item not found' } end

  return datum
end

function Store:get_diff()
  local datum, err = self:get()
  if err then return nil, err end
  if not datum then return nil, { 'no data found' } end

  local file = datum.file
  if not file then return nil, { 'No file found in item' } end

  local log = datum.log
  if not log then return nil, { 'No log found in item' } end

  local id = file.id
  local filename = file.filename
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash
  local current_commit = datum.commit

  if self.state.commits[id] then return self.state.commits[id] end

  local lines_err, lines
  local is_deleted = false

  loop.free_textlock()
  local reponame = git_repo.discover()
  if not git_repo.has(reponame, filename, commit_hash) then
    if not git_repo.has(reponame, filename, parent_hash) then
      lines, lines_err = git_show.lines(reponame, filename, current_commit)
    else
      is_deleted = true
      lines, lines_err = git_show.lines(reponame, filename, parent_hash)
    end
  else
    lines, lines_err = git_show.lines(reponame, filename, commit_hash)
  end
  loop.free_textlock()

  if lines_err then return nil, lines_err end

  local hunks_err, hunks
  if is_deleted then
    hunks = git_hunks.custom(lines, { deleted = true })
  else
    hunks, hunks_err = git_hunks.list(reponame, filename, {
      parent = parent_hash,
      current = commit_hash,
    })
  end
  loop.free_textlock()
  if hunks_err then return nil, hunks_err end

  local diff = Diff():generate(hunks, lines, self.shape, { is_deleted = is_deleted })

  self.state.commits[id] = diff

  return diff
end

function Store:get_filename()
  local datum, err = self:get()
  if err then return nil, err end

  return datum.file.filename
end

function Store:get_filetype()
  local datum, err = self:get()
  if err then return nil, err end

  return datum.file.filetype
end

function Store:get_lnum()
  return self.state.lnum
end

function Store:get_parent_commit()
  local datum, err = self:get()
  if err then return nil, err end

  local file = datum.file
  if not file then return nil, { 'No file found in item' } end

  local log = datum.log
  if not log then return nil, { 'No log found in item' } end

  return log.parent_hash
end

function Store:set_lnum(lnum)
  self.state.lnum = lnum
end

function Store:get_list_folds()
  return self.state.list_folds
end

function Store:set_list_folds(list_folds)
  self.state.list_folds = list_folds
end

return Store
