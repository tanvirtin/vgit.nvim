local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_repo = require('vgit.git.git_repo')

local GitRepository = Object:extend()

function GitRepository:constructor(path)
  local name, err = git_repo.discover(path)
  if err then error(string.format('failed to access .git at "%s"', path)) end

  return { name = name }
end

function GitRepository.exists(path)
  return git_repo.exists(path)
end

function GitRepository:logs(opts)
  opts = opts or {}

  return git_log.list(self.name, {
    from = opts.from,
    count = opts.count,
    stashed = opts.stashed,
  })
end

function GitRepository:state()
  local git_dir = string.format('%s/.git', self.name)

  if fs.exists(string.format('%s/rebase-apply/applying', git_dir)) then return 'APPLY-MAILBOX' end
  if fs.exists(string.format('%s/rebase-apply/rebasing', git_dir)) then return 'REBASE' end
  if fs.exists(string.format('%s/rebase-apply', git_dir)) then return 'APPLY-MAILBOX-REBASE' end
  if fs.exists(string.format('%s/rebase-merge/interactive', git_dir)) then return 'REBASE-INTERACTIVE' end
  if fs.exists(string.format('%s/rebase-merge', git_dir)) then return 'REBASE' end
  if fs.exists(string.format('%s/CHERRY_PICK_HEAD', git_dir)) then
    if fs.exists(string.format('%s/sequencer/todo', git_dir)) then return 'CHERRY-PICK-SEQUENCE' end
    return 'CHERRY-PICK'
  end
  if fs.exists(string.format('%s/MERGE_HEAD', git_dir)) then return 'MERGE' end
  if fs.exists(string.format('%s/BISECT_LOG', git_dir)) then return 'BISECT' end
  if fs.exists(string.format('%s/REVERT_HEAD', git_dir)) then
    if fs.exists(string.format('%s/sequencer/todo', git_dir)) then return 'REVERT-SEQUENCE' end
    return 'REVERT'
  end

  return nil
end

function GitRepository:commit(commit_hash) end

function GitRepository:tree(commit_hash) end

function GitRepository:file(commit_hash) end

return GitRepository
