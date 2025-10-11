local GitCommit = require('vgit.git.GitCommit')
local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_stash = {}

local git_log_format = '"%H\x1F%P\x1F%at\x1F%an\x1F%ae\x1F%s"'

local function parse_stash_line(line, reponame, revision_count)
  local parts = vim.split(line, '\x1F')
  local parents = vim.split(parts[2], ' ')
  local revision = revision_count and string.format('stash@{%s}', revision_count - 1)

  local parent_hash = parents[1]
  if parent_hash == '' then parent_hash = nil end

  return GitCommit({
    hash = parts[1]:sub(2, #parts[1]),
    parent_hash = parent_hash,
    author = parts[4],
    author_mail = parts[5],
    author_time = tonumber(parts[3]),
    message = parts[6]:sub(1, #parts[6] - 1),
    repository = reponame,
    context = {
      revision = revision,
      is_stash = true,
    },
  })
end

function git_stash.add(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return GitQueryBuilder(reponame):raw_arg('stash'):execute()
end

function git_stash.apply(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return GitQueryBuilder(reponame):raw_args('stash', 'apply', stash_index):execute()
end

function git_stash.pop(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return GitQueryBuilder(reponame):raw_args('stash', 'pop', stash_index):execute()
end

function git_stash.drop(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return GitQueryBuilder(reponame):raw_args('stash', 'drop', stash_index):execute()
end

function git_stash.clear(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return GitQueryBuilder(reponame):raw_args('stash', 'clear'):execute()
end

function git_stash.list(reponame, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local pagination = opts.pagination

  local query = GitQueryBuilder(reponame):stash():subcommand('list'):option('color', 'never'):pretty(git_log_format)

  if pagination then query:paginate(pagination.count, pagination.skip) end

  local result, err = query:execute()

  if err then return nil, err end

  local commits = {}
  local rev_count = pagination and pagination.skip or 0
  for i = 1, #result do
    rev_count = rev_count + 1
    commits[#commits + 1] = parse_stash_line(result[i], reponame, rev_count)
  end

  return commits
end

return git_stash
