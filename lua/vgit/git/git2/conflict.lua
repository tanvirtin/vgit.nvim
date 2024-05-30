local gitcli = require('vgit.git.git2.gitcli')

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
    filename
  })

  if err then return nil, err end
  return result and #result ~= 0
end

return git_conflict
