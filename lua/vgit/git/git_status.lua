local GitStatus = require('vgit.git.GitStatus')
local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_status = {}

function git_status.ls(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local query = GitQueryBuilder(reponame):status()

  if filename then
    query:file(filename)
  else
    query:file('.')
  end

  local cmd = 'git -C "' .. reponame .. '" --no-pager status -u -s --no-renames --ignore-submodules -- .'
  local handle = io.popen(cmd)
  if not handle then return nil, { 'Failed to execute git status command' } end

  local system_result = handle:read('*a')
  local success = handle:close()
  local system_exit_code = success and 0 or 1

  if system_exit_code ~= 0 then return nil, { 'git status failed with exit code ' .. system_exit_code } end

  local result = vim.split(system_result, '\n')
  result = vim.tbl_filter(function(line)
    return line ~= ''
  end, result)

  local result_len = #result
  local files = {}
  for i = 1, result_len do
    files[i] = GitStatus(result[i])
  end

  if filename then return files[1], nil end
  return files, nil
end

function git_status.tree(reponame, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local commit_hash = opts.commit_hash
  local parent_hash = opts.parent_hash
  local empty_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

  local result, err =
    GitQueryBuilder(reponame):diff_tree():refs(parent_hash == '' and empty_hash or parent_hash, commit_hash):execute()
  if err then return nil, err end

  local result_len = #result
  local files = {}
  for i = 1, result_len do
    local status, path = result[i]:match('(%w+)%s+(.+)')
    files[i] = GitStatus(status .. '  ' .. path)
  end

  return files
end

return git_status
