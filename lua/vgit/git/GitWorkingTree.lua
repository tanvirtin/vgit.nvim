local Object = require('vgit.core.Object')
local fs = require('vgit.core.fs')
local git_repo = require('vgit.git.git_repo')
local git_show = require('vgit.git.git_show')
local git_hunks = require('vgit.git.git_hunks')

local GitWorkingTree = Object:extend()

function GitWorkingTree:constructor(repository)
  if not repository then error('GitWorkingTree requires a repository') end

  local tree = {
    _repository = repository,
    _root_path = repository:get_path(),
  }

  return tree
end

function GitWorkingTree:root()
  return self._root_path
end

function GitWorkingTree:path(filename)
  if not filename then return self._root_path end
  return string.format('%s/%s', self._root_path, filename)
end

function GitWorkingTree:exists(filename)
  if not filename then return false end
  return fs.exists(self:path(filename))
end

function GitWorkingTree:read(filename)
  if not filename then return nil, { 'filename is required' } end

  local path = self:path(filename)
  if not fs.exists(path) then return nil, { 'file does not exist: ' .. filename } end

  return fs.read_file(path), nil
end

function GitWorkingTree:write(filename, lines)
  if not filename then return nil, { 'filename is required' } end

  if not lines then return nil, { 'lines are required' } end

  local path = self:path(filename)
  fs.write_file(path, lines)

  return true, nil
end

function GitWorkingTree:hunks(filename, commit)
  if not filename then return nil, { 'filename is required' } end

  commit = commit or 'HEAD'

  local original_lines, err = git_show.lines(self._repository:get_path(), filename, commit)

  if err then original_lines = {} end

  local current_lines = self:read(filename)
  if not current_lines then current_lines = {} end

  return git_hunks.live(self._repository:get_path(), original_lines, current_lines)
end

function GitWorkingTree:all_hunks(filename)
  return git_hunks.list(self._repository:get_path(), {
    staged = false,
    filename = filename,
  })
end

function GitWorkingTree:live_hunks(filename, current_lines)
  if not filename then return nil, { 'filename is required' } end
  if not current_lines then return nil, { 'current_lines is required' } end

  local git_repo = require('vgit.git.git_repo')
  local git_hunks = require('vgit.git.git_hunks')
  local git_show = require('vgit.git.git_show')

  local has_file, has_err = git_repo.has(self._root_path, filename)
  if has_err then return nil, has_err end

  if not has_file then
    local hunks, err = git_hunks.custom(current_lines, { untracked = true })
    if err then return nil, err end
    return hunks, nil
  end

  local original_lines, err = git_show.lines(self._root_path, filename, 'HEAD')
  if err then return nil, err end

  return git_hunks.live(self._root_path, original_lines, current_lines)
end

function GitWorkingTree:compare(filename, commit)
  if not filename then return nil, { 'filename is required' } end

  if not commit then return nil, { 'commit is required' } end

  local original_lines, err = git_show.lines(self._repository:get_path(), filename, commit)

  if err then return nil, err end

  local current_lines, read_err = self:read(filename)
  if read_err then return nil, read_err end

  local hunks, hunk_err = git_hunks.live(self._repository:get_path(), original_lines, current_lines)

  if hunk_err then return nil, hunk_err end

  return {
    original = original_lines,
    current = current_lines,
    hunks = hunks,
  }, nil
end

function GitWorkingTree:reset(filename)
  return git_repo.reset(self._repository:get_path(), filename)
end

function GitWorkingTree:clean(filename)
  return git_repo.clean(self._repository:get_path(), filename)
end

function GitWorkingTree:is_ignored(filename)
  if not filename then return nil, { 'filename is required' } end

  return self._repository:is_ignored(filename)
end

function GitWorkingTree:is_tracked(filename)
  if not filename then return nil, { 'filename is required' } end

  return self._repository:has_file(filename)
end

function GitWorkingTree:relative_path(absolute_path)
  if not absolute_path then return nil end

  local root = self._root_path
  if absolute_path:sub(1, #root) == root then
    local relative = absolute_path:sub(#root + 2)
    return relative
  end

  return nil
end

function GitWorkingTree:contains(path)
  if not path then return false end

  local absolute_path = path
  if not vim.startswith(path, '/') then absolute_path = self:path(path) end

  return vim.startswith(absolute_path, self._root_path)
end

function GitWorkingTree:stat(filename)
  if not filename then return nil, { 'filename is required' } end

  local path = self:path(filename)
  if not fs.exists(path) then return nil, { 'file does not exist: ' .. filename } end

  local stat = vim.loop.fs_stat(path)
  return stat, nil
end

return GitWorkingTree
