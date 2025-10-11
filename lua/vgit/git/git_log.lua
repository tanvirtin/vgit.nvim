local GitCommit = require('vgit.git.GitCommit')
local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_log = { format = '"%H\x1F%P\x1F%at\x1F%an\x1F%ae\x1F%s"' }

local function parse_log_line(line, reponame, revision_count)
  local parts = vim.split(line, '\x1F')
  local parents = vim.split(parts[2], ' ')
  local revision = revision_count and string.format('HEAD~%s', revision_count)

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
    },
  })
end

function git_log.get(reponame, commit)
  if not reponame then return nil, { 'reponame is required' } end
  if not commit then return nil, { 'commit is required' } end

  local result, err = GitQueryBuilder(reponame):show(commit):pretty(git_log.format):no_patch():execute()

  if err then return nil, err end
  return parse_log_line(result[1], reponame)
end

function git_log.list(reponame, opts)
  opts = opts or {}

  if not reponame then return nil, { 'reponame is required' } end

  local filename = opts.filename
  local pagination = opts.pagination

  local query = GitQueryBuilder(reponame):log():pretty(git_log.format)

  if pagination then query:paginate(pagination.count, pagination.skip) end

  if filename then query:file(filename) end

  local result, err = query:execute()
  if err then return nil, err end

  local result_len = #result
  local commits = {}
  for i = 1, result_len do
    commits[i] = parse_log_line(result[i], reponame, i - 1)
  end

  return commits
end

return git_log
