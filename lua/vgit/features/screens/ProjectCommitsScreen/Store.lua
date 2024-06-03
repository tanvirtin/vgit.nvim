local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git2.log')
local git_repo = require('vgit.git.git2.repo')
local git_show = require('vgit.git.git2.show')
local git_hunks = require('vgit.git.git2.hunks')
local git_status = require('vgit.git.git2.status')
local diff_service = require('vgit.services.diff')

local Store = Object:extend()

function Store:constructor()
  return {
    id = nil,
    err = nil,
    data = nil,
    shape = nil,
    _cache = {
      lnum = 1,
      list_entry_cache = {},
      commits = {},
    },
  }
end

function Store:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self._cache = {
    lnum = 1,
    list_entry_cache = {},
    commits = {},
  }

  return self
end

function Store:fetch(shape, commits, opts)
  opts = opts or {}

  self:reset()

  if not commits or #commits == 0 then return { 'No commits specified' }, nil end

  self._cache = {
    lnum = 1,
    list_entry_cache = {},
    commits = {},
  }

  if not git_repo.exists() then return { 'Project has no .git folder' }, nil end

  self.shape = shape
  local data = {}

  for i = 1, #commits do
    local commit = commits[i]
    loop.free_textlock()
    local reponame = git_repo.discover()
    local log, log_err = git_log.get(reponame, commit)

    if log_err then return log_err end

    -- We will use the parent_hash and the commit_hash inside
    -- the log object to list all the files associated with the log.
    loop.free_textlock()
    local files, err = git_status.tree(reponame, {
      commit_hash = log.commit_hash,
      parent_hash = log.parent_hash,
    })
    if err then return err end

    data[commit] = utils.list.map(files, function(file)
      -- Log contains the metadata about parent_hash and commit_hash
      -- File contains the name of the file in that particular working tree.
      -- Using commit_hash, parent_hash and the name of the file we can easily get the lines
      -- and hunks to recreate the diffs by feeding this info into our algorithm.
      local datum = {
        id = utils.math.uuid(),
        log = log,
        file = file,
      }
      self._cache.commits[datum.id] = datum

      return datum
    end)
  end

  self.data = data

  return nil, self.data
end

function Store:get_all()
  return self.err, self.data
end

function Store:set_id(id)
  self.id = id

  return self
end

function Store:get(id)
  if id then self.id = id end

  local datum = self._cache.commits[self.id]

  if not datum then return { 'Item not found' }, nil end

  return nil, datum
end

function Store:get_diff_dto()
  local err, datum = self:get()

  if err then return err end

  local file = datum.file
  if not file then return { 'No file found in item' }, nil end

  local log = datum.log
  if not log then return { 'No log found in item' }, nil end

  local id = file.id
  local filename = file.filename
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  if self._cache.commits[id] then return nil, self._cache.commits[id] end

  local lines_err, lines
  local is_deleted = false

  loop.free_textlock()
  local reponame = git_repo.discover()
  if not git_repo.has(reponame, filename, commit_hash) then
    is_deleted = true
    lines, lines_err = git_show.lines(reponame, filename, parent_hash)
  else
    lines, lines_err = git_show.lines(reponame, filename, commit_hash)
  end
  loop.free_textlock()

  if lines_err then return lines_err end

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

  if hunks_err then return hunks_err end

  local diff = diff_service:generate(hunks, lines, self.shape, {
    is_deleted = is_deleted,
  })

  self._cache.commits[id] = diff

  return nil, diff
end

function Store:get_filename()
  local err, datum = self:get()

  if err then return err end

  return nil, datum.file.filename
end

function Store:get_filetype()
  local err, datum = self:get()

  if err then return err end

  return nil, datum.file.filetype
end

function Store:get_lnum()
  return nil, self._cache.lnum
end

function Store:get_parent_commit()
  local err, datum = self:get()
  if err then return err end

  local file = datum.file
  if not file then return { 'No file found in item' }, nil end

  local log = datum.log
  if not log then return { 'No log found in item' }, nil end

  return nil, log.parent_hash
end

function Store:set_lnum(lnum)
  self._cache.lnum = lnum

  return self
end

function Store:get_list_folds()
  return nil, self._cache.list_folds
end

function Store:set_list_folds(list_folds)
  self._cache.list_folds = list_folds

  return self
end

return Store
