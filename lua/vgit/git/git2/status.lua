local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local gitcli = require('vgit.git.git2.gitcli')

local File = Object:extend()

function File:constructor(filename, status)
  filename = filename:gsub('"', '')
  local is_dir = fs.is_dir(filename)
  local dirname = fs.dirname(filename)
  local filetype = fs.detect_filetype(filename)

  return {
    id = utils.math.uuid(),
    is_dir = is_dir,
    dirname = dirname,
    filename = filename,
    filetype = filetype,
    status = status,
  }
end

function File:is_ignored()
  return self.status:has('!!')
end

function File:is_staged()
  return self.status:has('* ')
end

function File:is_unstaged()
  return self.status:has(' *')
end

function File:is_untracked()
  return self.status:has('??')
end

function File:is_unmerged()
  return self.status:has_either('UU')
end

local Status = Object:extend()

function Status:constructor(value)
  local first, second = Status:parse(value)

  return {
    id = utils.math.uuid(),
    value = value,
    first = first,
    second = second,
  }
end

function Status:parse(status)
  return status:sub(1, 1), status:sub(2, 2)
end

function Status:has(status)
  local first, second = self:parse(status)
  local actual_status = self.value
  local actual_first, actual_second = self.first, self.second

  if actual_first ~= ' ' then
    if first == '*' then
      return true
    end
    if first == actual_first then
      return true
    end
  end

  if actual_second ~= ' ' then
    if second == '*' then
      return true
    end
    if second == actual_second then
      return true
    end
  end

  return status == '**' or status == actual_status
end

function Status:has_either(status)
  local first, second = self:parse(status)

  return first == self.first or second == self.second
end

function Status:has_both(status)
  local first, second = self:parse(status)

  return first == self.first and second == self.second
end

function Status:to_string()
  return self.value
end

function Status:is_unchanged()
  return self.value == '--'
end

local status = {}

function status.ls(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end
  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'status',
    '-u',
    '-s',
    '--no-renames',
    '--ignore-submodules',
    '--',
    filename or '.',
  })
  if err then return nil, err end

  local files = {}
  for i = 1, #result do
    local line = result[i]
    files[#files + 1] = File(line:sub(4, #line), Status(line:sub(1, 2)))
  end

  if filename then return files[1] end
  return files
end

function status.tree(reponame, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local commit_hash = opts.commit_hash
  local parent_hash = opts.parent_hash
  local empty_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'diff-tree',
    '--no-commit-id',
    '--name-only',
    '-r',
    commit_hash,
    parent_hash == '' and empty_hash or parent_hash,
  })
  if err then return nil, err end

  local files = {}
  for i = 1, #result do
    local line = result[i]
    files[#files + 1] = File(line, Status('--'))
  end

  return files
end

return status
