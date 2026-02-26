local lazy = require('vgit.core.lazy')

local GitStatus = lazy('vgit.git.GitStatus')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_status = {}

function git_status.ls(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local query = GitQueryBuilder(reponame):status()

  if filename then
    query:file(filename)
  else
    query:file('.')
  end

  local result, err = query:execute()
  if err then return nil, err end

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
    local line = result[i]
    local status, path = line:match('(%w+)%s+(.+)')
    if not status then goto continue end

    -- Normalize rename/copy status (e.g., R100 -> R, C100 -> C)
    -- and convert tab-separated paths to arrow format for GitStatus
    local status_char = status:sub(1, 1)
    if (status_char == 'R' or status_char == 'C') and #status > 1 then
      local old_path, new_path = path:match('(.+)\t(.+)')
      if old_path and new_path then
        path = old_path .. ' -> ' .. new_path
      end
      status = status_char .. ' '
    else
      status = status:sub(1, 1) .. ' '
    end

    files[#files + 1] = GitStatus(status .. ' ' .. path)
    ::continue::
  end

  return files
end

return git_status
