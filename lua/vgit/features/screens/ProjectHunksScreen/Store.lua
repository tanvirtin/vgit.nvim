local fs = require('vgit.core.fs')
local Diff = require('vgit.core.Diff')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
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
    list_entry_cache = {},
  }
end

function Store:fetch(shape, opts)
  opts = opts or {}

  self:reset()

  if not git_repo.exists() then return nil, { 'Project has no .git folder' } end

  local reponame = git_repo.discover()
  local files, files_err = git_status.ls(reponame)

  if files_err then return nil, files_err end
  if #files == 0 then return nil, { 'No files found' } end

  local data = {}
  local is_empty = true

  for i = 1, #files do
    local file = files[i]
    local status = file.status

    local lines, lines_err = self:get_lines(file)
    if lines_err then return nil, lines_err end

    local hunks, hunks_err = self:get_hunks(file, lines, opts.is_staged)
    if hunks_err then return nil, hunks_err end

    if hunks and #hunks > 0 then
      is_empty = false

      local entry = data[file.filename] or {}
      data[file.filename] = entry

      local is_deleted = status and status:has_either('DD')
      local diff = Diff():generate(hunks, lines, shape, { is_deleted = is_deleted })

      utils.list.each(hunks, function(hunk, index)
        local id = utils.math.uuid()
        local data = {
          id = id,
          hunk = hunk,
          file = file,
          mark_index = index,
          diff = diff,
        }

        self.state.list_entry_cache[id] = data
        entry[#entry + 1] = data
      end)
    end
  end

  if is_empty then return nil, { 'No files found' } end

  self.data = data

  return self.data, self.err
end

function Store:set_id(id)
  self.id = id
end

function Store:get_data(id)
  if id then self.id = id end

  local data = self.state.list_entry_cache[self.id]
  if not data then return nil, { 'Item not found' } end

  return data
end

function Store:get_all()
  return self.data, self.err
end

function Store:get_diff()
  local data, data_err = self:get_data()
  if data_err then return nil, data_err end

  if not data.diff then return nil, { 'No git file found to get code dto from' } end
  return data.diff
end

function Store:get_filename()
  local data, data_err = self:get_data()
  if data_err then return nil, data_err end

  local file = data.file
  local filename = file.filename or ''

  return filename
end

function Store:get_filetype()
  local data, data_err = self:get_data()
  if data_err then return nil, data_err end

  local file = data.file
  local filetype = file.filetype or ''

  return filetype
end

function Store:get_lines(file)
  local status = file.status
  local filename = file.filename

  local lines_err, lines

  if status then
    if status:has('D ') then
      local reponame = git_repo.discover()
      lines, lines_err = git_show.lines(reponame, filename, 'HEAD')
    elseif status:has(' D') then
      local reponame = git_repo.discover()
      lines, lines_err = git_show.lines(reponame, filename)
    else
      lines, lines_err = fs.read_file(filename)
    end
  else
    lines, lines_err = fs.read_file(filename)
  end

  return lines, lines_err
end

function Store:get_hunks(file, lines, is_staged)
  local log = file.log
  local status = file.status
  local filename = file.filename

  if is_staged then
    if file:is_staged() then
      local reponame = git_repo.discover()
      return git_hunks.list(reponame, filename)
    end
    return nil
  end

  local hunks_err, hunks
  local reponame = git_repo.discover()
  if status then
    if status:has_both('??') then
      hunks = git_hunks.custom(lines, { untracked = true })
    elseif status:has_either('DD') then
      hunks = git_hunks.custom(lines, { deleted = true })
    else
      hunks, hunks_err = git_hunks.list(reponame, filename)
      return hunks, hunks_err
    end
  elseif log then
    hunks, hunks_err = git_hunks.list(filename, {
      parent = log.parent_hash,
      current = log.commit_hash,
    })
  else
    hunks, hunks_err = git_hunks.list(reponame, filename)
  end

  return hunks, hunks_err 
end

function Store:get_lnum()
  return self.state.lnum
end

function Store:set_lnum(lnum)
  self.state.lnum = lnum
  return self
end

function Store:get_list_folds()
  return self.state.list_folds
end

function Store:set_list_folds(list_folds)
  self.state.list_folds = list_folds
end

return Store
