local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local GitBlame = Object:extend()

GitBlame.empty_commit_hash = '0000000000000000000000000000000000000000'

function GitBlame:constructor(info)
  local header = utils.str.split(info[1], ' ')
  local blame = {
    lnum = tonumber(header[2]),
    commit = header[1],
  }

  for i = 2, #info do
    local blame_info = utils.str.split(info[i], ' ')
    blame[blame_info[1]] = blame_info[2]
  end

  local committed = true

  if blame.commit == GitBlame.empty_commit_hash then committed = false end

  local author_mail = blame['author-mail']
  if author_mail:sub(1, 1) == '<' and author_mail:sub(#author_mail, #author_mail) then
    author_mail = author_mail:sub(2, #author_mail - 1)
  end

  local commit_mail = blame['committer-mail']
  if commit_mail:sub(1, 1) == '<' and commit_mail:sub(#commit_mail, #commit_mail) then
    commit_mail = commit_mail:sub(2, #commit_mail - 1)
  end

  return {
    id = utils.math.uuid(),
    lnum = blame.lnum,
    filename = blame.filename,
    commit_hash = blame.commit,
    parent_hash = blame.previous,
    author = blame.author,
    author_mail = author_mail,
    author_time = tonumber(blame['author-time']),
    author_tz = blame['author-tz'],
    committer = blame.committer,
    committer_mail = commit_mail,
    committer_time = tonumber(blame['committer-time']),
    committer_tz = blame['committer-tz'],
    commit_message = info[10]:sub(9, #info[10]),
    committed = committed,
  }
end

function GitBlame:age()
  return utils.date.age(self.author_time)
end

function GitBlame:is_uncommitted()
  return self.commit_hash == GitBlame.empty_commit_hash
end

function GitBlame:is_committed()
  return not self:is_uncommitted()
end

return GitBlame
