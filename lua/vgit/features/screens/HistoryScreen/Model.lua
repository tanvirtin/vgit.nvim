local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Model = Object:extend()

function Model:constructor(opts)
  return {
    git_object = nil,
    state = {
      config = nil,
      entries = nil,
      entry_index = 1,
      layout_type = opts.layout_type or 'unified',
    },
  }
end

function Model:reset()
  self.state = {
    config = nil,
    entries = nil,
    entry_index = 1,
    layout_type = self.state.layout_type,
  }
end

function Model:get_layout_type()
  return self.state.layout_type
end

function Model:fetch(filename, opts)
  opts = opts or {}

  if not filename or filename == '' then return nil, { 'Buffer has no history associated with it' } end

  self:reset()

  self.git_object = GitObject(filename)

  local entries, err = self.git_object:logs()
  if err then return nil, err end

  local config, err = self.git_object:config()
  if err then return nil, err end

  self.state.config = config
  self.state.entries = entries

  if entries and utils.list.is_empty(entries) then
    return nil, { 'There is no history associated with this buffer' }
  end

  return entries, err
end

function Model:get_config()
  return self.state.config
end

function Model:get_entries()
  return self.state.entries
end

function Model:set_entry_index(index)
  self.state.entry_index = index
end

function Model:get_diff()
  local log = self.state.entries[self.state.entry_index]
  if not log then return nil end

  local id = log.id
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  if self.state[id] then return self.state[id] end

  local hunks, hunks_err = self.git_object:list_hunks({
    parent = parent_hash,
    current = commit_hash,
  })
  loop.free_textlock()

  if hunks_err then return nil, hunks_err end

  local lines, lines_err = self.git_object:lines(commit_hash)
  loop.free_textlock()

  if lines_err then return nil, lines_err end

  -- TODO(renames): If a file is renamed changes are not reflected.
  local diff = Diff():generate(hunks, lines, self:get_layout_type())

  self.state[id] = diff

  return diff
end

function Model:get_filename()
  return self.git_object:get_filename()
end

function Model:get_filetype()
  return self.git_object:get_filetype()
end

return Model
