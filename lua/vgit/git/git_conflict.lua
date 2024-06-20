local fs = require('vgit.core.fs')
local gitcli = require('vgit.git.gitcli')

local git_conflict = {}

function git_conflict.match_line(line, marker)
  return line:match(string.format('^%s', marker))
end

function git_conflict.parse(lines)
  local conflicts = {}
  local markers = {
    start = '<<<<<<<',
    middle = '=======',
    finish = '>>>>>>>',
    ancestor = '|||||||',
  }

  local conflict = nil
  local has_start = false
  local has_middle = false
  local has_ancestor = false

  for lnum, line in ipairs(lines) do
    if git_conflict.match_line(line, markers.start) then
      has_start = true

      conflict = {
        current = { top = lnum },
        middle = {},
        incoming = {},
        ancestor = {},
      }
    end

    if has_start and git_conflict.match_line(line, markers.ancestor) then
      has_ancestor = true

      conflict.ancestor.top = lnum
      conflict.current.bot = lnum - 1
    end

    if has_start and git_conflict.match_line(line, markers.middle) then
      has_middle = true

      if has_ancestor then
        conflict.ancestor.bot = lnum - 1
      else
        conflict.current.bot = lnum - 1
      end

      conflict.middle.top = lnum
      conflict.middle.bot = lnum + 1
      conflict.incoming.top = lnum + 1
    end

    if has_start and has_middle and git_conflict.match_line(line, markers.finish) then
      conflict.incoming.bot = lnum

      conflicts[#conflicts + 1] = conflict

      conflict = nil
      has_start = false
      has_middle = false
      has_ancestor = false
    end
  end

  return conflicts
end

function git_conflict.has_conflict(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local result, err = gitcli.run({
    '-C',
    reponame,
    'ls-files',
    '-u',
    '--',
    filename,
  })

  if err then return nil, err end
  return result and #result ~= 0
end

function git_conflict.status(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local git_dir = string.format('%s/.git', reponame)
  -- is_file
  if fs.exists(string.format('%s/rebase-apply/applying', git_dir)) then return 'APPLY-MAILBOX' end
  -- is_file
  if fs.exists(string.format('%s/rebase-apply/rebasing', git_dir)) then return 'REBASE' end
  -- is_dir
  if fs.exists(string.format('%s/rebase-apply', git_dir)) then return 'APPLY-MAILBOX-REBASE' end
  -- is_file
  if fs.exists(string.format('%s/rebase-merge/interactive', git_dir)) then return 'REBASE-INTERACTIVE' end
  -- is_dir
  if fs.exists(string.format('%s/rebase-merge', git_dir)) then return 'REBASE' end
  -- is_file
  if fs.exists(string.format('%s/CHERRY_PICK_HEAD', git_dir)) then
    -- is_file
    if fs.exists(string.format('%s/sequencer/todo', git_dir)) then return 'CHERRY-PICK-SEQUENCE' end
    return 'CHERRY-PICK'
  end
  -- is_file
  if fs.exists(string.format('%s/MERGE_HEAD', git_dir)) then return 'MERGE' end
  -- is_file
  if fs.exists(string.format('%s/BISECT_LOG', git_dir)) then return 'BISECT' end
  -- is_file
  if fs.exists(string.format('%s/REVERT_HEAD', git_dir)) then
    -- is_file
    if fs.exists(string.format('%s/sequencer/todo', git_dir)) then return 'REVERT-SEQUENCE' end
    return 'REVERT'
  end

  return nil
end

return git_conflict
