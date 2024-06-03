local fs = require('vgit.core.fs')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = {},
    shape = nil,
    git_object = nil,
    state = {
      lines = {},
      diff = nil,
    },
  }
end

function Store:reset()
  self.err = nil
  self.data = {}
  self.state = {
    lines = {},
    diff = nil,
  }

  return self
end

function Store:fetch(shape, filename, opts)
  opts = opts or {}

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)

  local parent = nil
  local current = nil
  local has_conflict = self.git_object:has_conflict()

  if has_conflict and opts.is_staged then
    self.state.lines = {}
    self.data = {}
    self.err = nil

    return
  end

  if has_conflict then
    local head_log, head_log_err = self.git_object:log({ rev = 'HEAD' })
    if head_log_err then
      self.err = head_log_err
      return head_log_err
    end
    local merge_log, merge_log_err = self.git_object:log({ rev = 'MERGE_HEAD' })
    if merge_log_err then
      self.err = merge_log_err
      return merge_log_err
    end
    parent = head_log.commit_hash
    current = merge_log.commit_hash
  end

  local lines_err, lines
  if opts.is_staged then
    lines, lines_err = self.git_object:lines()
  elseif has_conflict then
    lines, lines_err = self.git_object:lines(current)
  else
    lines, lines_err = fs.read_file(filename)
  end

  if lines_err then
    self.err = lines_err

    return lines_err
  end

  if opts.is_staged then
    self.data, self.err = self.git_object:list_hunks({ staged = true })
  elseif has_conflict then
    self.data, self.err = self.git_object:list_hunks({ parent = parent, current = current })
  else
    self.data, self.err = self.git_object:live_hunks(lines)
  end

  self.state.lines = lines

  return self.err, self.data
end

function Store:get_diff()
  if self.state.diff then return nil, self.state.diff end

  self.state.diff = Diff():generate(self.data, self.state.lines, self.shape)

  return nil, self.state.diff
end

function Store:get_filename()
  return nil, self.git_object:get_filename()
end

function Store:get_filetype()
  return nil, self.git_object:get_filetype()
end

return Store
