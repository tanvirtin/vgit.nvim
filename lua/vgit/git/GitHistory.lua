local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local git_log = lazy('vgit.git.git_log')

local GitHistory = Object:extend()

function GitHistory:constructor(repository, opts)
  if not repository then error('GitHistory requires a repository') end

  opts = opts or {}

  local history = {
    ['$_repo_path'] = repository:get_path(),
    ['$_from'] = opts.from or 'HEAD',
    ['$_count'] = opts.count,
    ['$_path'] = opts.path,
    ['$_skip'] = opts.skip or 0,
    _commits = nil,
  }

  return history
end

function GitHistory:commits()
  if not self._commits then
    local pagination = nil
    if self._count then pagination = {
      count = self._count,
      skip = self._skip,
    } end

    local logs, err = git_log.list(self._repo_path, {
      filename = self._path,
      pagination = pagination,
    })

    if err then return nil, err end
    self._commits = logs
  end

  return self._commits, nil
end

function GitHistory:at(index)
  if not index or index < 1 then return nil, { 'valid index is required' } end

  local commits, err = self:commits()
  if err then return nil, err end

  if index > #commits then return nil, { 'index out of bounds' } end

  return commits[index], nil
end

function GitHistory:first()
  return self:at(1)
end

function GitHistory:last()
  local commits, err = self:commits()
  if err then return nil, err end

  return commits[#commits], nil
end

function GitHistory:count()
  local commits, err = self:commits()
  if err then return nil, err end

  return #commits, nil
end

function GitHistory:is_empty()
  local commits, err = self:commits()
  if err then return true end

  return #commits == 0
end

function GitHistory:by_author(author_name)
  if not author_name then return nil, { 'author name is required' } end

  local commits, err = self:commits()
  if err then return nil, err end

  local filtered = {}
  local filtered_len = 0
  for _, commit in ipairs(commits) do
    if commit.author_name == author_name then
      filtered_len = filtered_len + 1
      filtered[filtered_len] = commit
    end
  end

  return filtered, nil
end

function GitHistory:by_date_range(start_timestamp, end_timestamp)
  if not start_timestamp or not end_timestamp then return nil, { 'start and end timestamps are required' } end

  local commits, err = self:commits()
  if err then return nil, err end

  local filtered = {}
  local filtered_len = 0
  for _, commit in ipairs(commits) do
    local timestamp = tonumber(commit.timestamp)
    if timestamp >= start_timestamp and timestamp <= end_timestamp then
      filtered_len = filtered_len + 1
      filtered[filtered_len] = commit
    end
  end

  return filtered, nil
end

function GitHistory:search(pattern)
  if not pattern then return nil, { 'pattern is required' } end

  local commits, err = self:commits()
  if err then return nil, err end

  local filtered = {}
  local filtered_len = 0
  for _, commit in ipairs(commits) do
    if commit.summary:match(pattern) then
      filtered_len = filtered_len + 1
      filtered[filtered_len] = commit
    end
  end

  return filtered, nil
end

function GitHistory:authors()
  local commits, err = self:commits()
  if err then return nil, err end

  local authors = {}
  local authors_len = 0
  local seen = {}

  for _, commit in ipairs(commits) do
    local email = commit.author_email
    if not seen[email] then
      authors_len = authors_len + 1
      authors[authors_len] = {
        name = commit.author_name,
        email = email,
      }
      seen[email] = true
    end
  end

  return authors, nil
end

function GitHistory:iter()
  local commits, _ = self:commits()
  if not commits then return function()
    return nil
  end end

  local i = 0
  return function()
    i = i + 1
    if i <= #commits then return i, commits[i] end
    return nil
  end
end

function GitHistory:load_more(additional_count)
  if not additional_count or additional_count < 1 then return nil, { 'valid count is required' } end

  local current_count = 0
  if self._commits then current_count = #self._commits end

  local pagination = {
    count = additional_count,
    skip = current_count,
  }

  local logs, err = git_log.list(self._repo_path, {
    filename = self._path,
    pagination = pagination,
  })

  if err then return nil, err end

  if not self._commits then self._commits = {} end

  local commits_len = #self._commits
  for i = 1, #logs do
    commits_len = commits_len + 1
    self._commits[commits_len] = logs[i]
  end

  return logs, nil
end

function GitHistory:reset()
  self._commits = nil
end

return GitHistory
