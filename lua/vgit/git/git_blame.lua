local lazy = require('vgit.core.lazy')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')
local GitCommit = lazy('vgit.git.GitCommit')
local utils = lazy('vgit.core.utils')

local git_blame = {}

local function parse_blame(blame_lines, filename)
  local str_split = utils.str.split
  local header = str_split(blame_lines[1], ' ')
  local blame_data = {
    lnum = tonumber(header[2]),
    commit_hash = header[1],
  }

  local blame_lines_len = #blame_lines
  for i = 2, blame_lines_len do
    local parts = str_split(blame_lines[i], ' ')
    local key = parts[1]

    if key == 'previous' then
      blame_data[key] = parts[2]
      if #parts >= 3 then
        local filename_parts = {}
        for k = 3, #parts do
          filename_parts[#filename_parts + 1] = parts[k]
        end
        blame_data['previous_filename'] = table.concat(filename_parts, ' ')
      end
    else
      local value_parts = {}
      local parts_len = #parts
      for j = 2, parts_len do
        value_parts[j - 1] = parts[j]
      end
      blame_data[key] = table.concat(value_parts, ' ')
    end
  end

  local author_mail = blame_data['author-mail']
  if author_mail and author_mail:sub(1, 1) == '<' and author_mail:sub(#author_mail, #author_mail) == '>' then
    author_mail = author_mail:sub(2, #author_mail - 1)
  end

  local committer_mail = blame_data['committer-mail']
  if
    committer_mail
    and committer_mail:sub(1, 1) == '<'
    and committer_mail:sub(#committer_mail, #committer_mail) == '>'
  then
    committer_mail = committer_mail:sub(2, #committer_mail - 1)
  end

  local commit_message = ''
  if #blame_lines >= 10 and blame_lines[10]:match('^summary ') then
    commit_message = blame_lines[10]:sub(9, #blame_lines[10])
  end
  return GitCommit({
    hash = blame_data.commit_hash,
    parent_hash = blame_data.previous,
    author = blame_data.author,
    author_mail = author_mail,
    author_time = tonumber(blame_data['author-time']),
    author_tz = blame_data['author-tz'],
    committer = blame_data.committer,
    committer_mail = committer_mail,
    committer_time = tonumber(blame_data['committer-time']),
    committer_tz = blame_data['committer-tz'],
    message = commit_message,
    repository = blame_data.filename and vim.fn.fnamemodify(blame_data.filename, ':h'),
    context = {
      lnum = blame_data.lnum,
      filename = filename or blame_data.filename,
      previous_filename = blame_data.previous_filename,
    },
  })
end

function git_blame.list(reponame, filename, commit)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  commit = commit or 'HEAD'

  local lines, err = GitQueryBuilder(reponame):blame():raw_args('--line-porcelain', commit):file(filename):execute()

  if err then return nil, err end

  local commits = {}
  local commits_len = 0
  local blame_info = {}
  local blame_info_len = 0
  for i = 1, #lines do
    local line = lines[i]

    if string.byte(line:sub(1, 3)) ~= 9 then
      blame_info_len = blame_info_len + 1
      blame_info[blame_info_len] = line
    else
      commits_len = commits_len + 1
      commits[commits_len] = parse_blame(blame_info, filename)
      blame_info = {}
      blame_info_len = 0
    end
  end

  return commits
end

function git_blame.get(reponame, filename, lnum)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  if not lnum then return nil, { 'lnum is required' } end

  local blame_info, err = GitQueryBuilder(reponame)
    :blame()
    :raw_args('-L', string.format('%s,+1', lnum), '--line-porcelain')
    :file(filename)
    :execute()

  if err then return nil, err end

  return parse_blame(blame_info, filename)
end

return git_blame
