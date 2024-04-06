local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local gitcli = require('vgit.git.git2.gitcli')

local Log = Object:extend()

function Log:constructor(line, revision_count)
  local log = vim.split(line, '-')
  local parents = vim.split(log[2], ' ')
  local revision = revision_count and string.format('HEAD~%s', revision_count)

  if #parents > 1 then
    log[2] = parents[1]
  end

  return {
    id = utils.math.uuid(),
    revision = revision,
    commit_hash = log[1]:sub(2, #log[1]),
    parent_hash = log[2],
    timestamp = log[3],
    author_name = log[4],
    author_email = log[5],
    summary = log[6]:sub(1, #log[6] - 1),
  }
end

local log = { format = '--pretty=format:"%H-%P-%at-%an-%ae-%s"' }

function log.get(reponame, commit)
  if not reponame then return nil, { 'reponame is required' } end
  if not commit then return nil, { 'commit is required' } end

  local result, err = gitcli.run({
    '-C',
    reponame,
    'show',
    commit,
    '--color=never',
    log.format,
    '--no-patch',
  })

  if err then return nil, err end
  return Log(result[1]), nil
end

function log.list(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'log',
    '--color=never',
    log.format,
    filename,
  })

  if err then return nil, err end

  local logs = {}
  for i = 1, #result do
    logs[i] = Log(result[i])
  end

  return logs, nil
end

function log.list_stash(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'stash',
    'list',
    '--color=never',
    log.format,
  })

  if err then return nil, err end

  local logs = {}
  local rev_count = 0
  for i = 1, #result do
    rev_count = rev_count + 1
    logs[i] = Log(result[i], rev_count)
  end

  return logs, nil
end

return log
