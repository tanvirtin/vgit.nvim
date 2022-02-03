local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Blame = Object:extend()

local function split_by_whitespace(str)
  return vim.split(str, ' ')
end

function Blame:new(info)
  if not info then
    return setmetatable({}, Blame)
  end
  -- TODO this is badly done crashes randomly please fix this parsing.
  local commit_hash_info = split_by_whitespace(info[1])
  local author_mail_info = split_by_whitespace(info[3])
  local author_time_info = split_by_whitespace(info[4])
  local author_tz_info = split_by_whitespace(info[5])
  local committer_mail_info = split_by_whitespace(info[7])
  local committer_time_info = split_by_whitespace(info[8])
  local committer_tz_info = split_by_whitespace(info[9])
  local parent_hash_info = split_by_whitespace(info[11])
  local author = info[2]:sub(8, #info[2])
  local author_mail = author_mail_info[2]
  local committer = info[6]:sub(11, #info[6])
  local committer_mail = committer_mail_info[2]
  local lnum = tonumber(commit_hash_info[3] or '1')
  local committed = true
  if
    author == 'Not Committed Yet'
    and committer == 'Not Committed Yet'
    and author_mail == '<not.committed.yet>'
    and committer_mail == '<not.committed.yet>'
  then
    committed = false
  end
  return setmetatable({
    lnum = lnum,
    commit_hash = commit_hash_info[1],
    parent_hash = parent_hash_info[2],
    author = author,
    author_mail = (function()
      local mail = author_mail
      if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
        mail = mail:sub(2, #mail - 1)
      end
      return mail
    end)(),
    author_time = tonumber(author_time_info[2]),
    author_tz = author_tz_info[2],
    committer = committer,
    committer_mail = (function()
      local mail = committer_mail
      if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
        mail = mail:sub(2, #mail - 1)
      end
      return mail
    end)(),
    committer_time = tonumber(committer_time_info[2]),
    committer_tz = committer_tz_info[2],
    commit_message = info[10]:sub(9, #info[10]),
    committed = committed,
  }, Blame)
end

function Blame:age()
  return utils.time.age(self.author_time)
end

return Blame
