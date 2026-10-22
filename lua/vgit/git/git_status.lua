local lazy = require('vgit.core.lazy')

local GitCommit = lazy('vgit.git.GitCommit')
local GitStatus = lazy('vgit.git.GitStatus')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_status = {}

function git_status.start(reponame, filename)
  return GitQueryBuilder(reponame):status():file(filename or '.'):start():map(function(result)
    local files = {}
    for i = 1, #result do
      files[i] = GitStatus(result[i])
    end
    return files, nil
  end)
end

function git_status.ls(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local files, err = git_status.start(reponame, filename):wait()
  if err then return nil, err end

  if filename then return files[1], nil end
  return files, nil
end

function git_status.tree(reponame, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local commit_hash = opts.commit_hash
  local parent_hash = opts.parent_hash

  local result, err =
    GitQueryBuilder(reponame):diff_tree():refs(parent_hash == '' and GitCommit.EMPTY_TREE_HASH or parent_hash, commit_hash):execute()
  if err then return nil, err end

  local result_len = #result
  local files = {}
  for i = 1, result_len do
    local line = result[i]
    local status, path = line:match('(%w+)%s+(.+)')
    if not status then goto continue end

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
