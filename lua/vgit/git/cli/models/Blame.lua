local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Blame = Object:extend()

Blame.empty_commit_hash = '0000000000000000000000000000000000000000'

function Blame:parse_author_mail(mail)
  if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
    mail = mail:sub(2, #mail - 1)
  end
  return mail
end

function Blame:parse_committer_mail(mail)
  if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
    mail = mail:sub(2, #mail - 1)
  end
  return mail
end

function Blame:constructor(info)
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

  if blame.commit == Blame.empty_commit_hash then
    committed = false
  end

  return {
    id = utils.math.uuid(),
    lnum = blame.lnum,
    filename = blame.filename,
    commit_hash = blame.commit,
    parent_hash = blame.previous,
    author = blame.author,
    author_mail = self:parse_author_mail(blame['author-mail']),
    author_time = tonumber(blame['author-time']),
    author_tz = blame['author-tz'],
    committer = blame.committer,
    committer_mail = self:parse_committer_mail(blame['committer-mail']),
    committer_time = tonumber(blame['committer-time']),
    committer_tz = blame['committer-tz'],
    commit_message = info[10]:sub(9, #info[10]),
    committed = committed,
  }
end

function Blame:age() return utils.date.age(self.author_time) end

function Blame:is_uncommitted() return self.commit_hash == Blame.empty_commit_hash end

return Blame
