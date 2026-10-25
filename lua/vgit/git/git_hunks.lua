local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local engine = lazy('vgit.core.diff.engine')
local gitcli = lazy('vgit.git.gitcli')
local GitHunk = lazy('vgit.git.GitHunk')
local GitCommit = lazy('vgit.git.GitCommit')
local git_setting = lazy('vgit.settings.git')

local git_hunks = {}

function git_hunks.live(_, original_lines, current_lines, opts)
  opts = opts or {}

  return engine.live(original_lines, current_lines, {
    algorithm = opts.algorithm or git_setting:get('algorithm'),
    engine = opts.engine,
  })
end

function git_hunks.custom(lines, opts)
  return engine.custom(lines, opts)
end

function git_hunks.list(reponame, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local staged = opts.staged
  local current = opts.current
  local parent = opts.parent
  local filename = opts.filename

  local filenames = opts.filenames
  if filenames and #filenames ~= 2 then return nil, { 'incorrect number of files provided' } end

  local args = {
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', git_setting:get('algorithm')),
    '--patch-with-raw',
    '--unified=0',
  }

  if staged == true then utils.list.concat(args, { '--cached' }) end
  if filenames then
    utils.list.concat(args, { '--no-index' }, filenames)
  elseif parent and current then
    utils.list.concat(args, {
      #parent > 0 and parent or GitCommit.EMPTY_TREE_HASH,
      current,
    })
  elseif parent and not current then
    utils.list.concat(args, { parent })
  end

  utils.list.concat(args, {
    '--',
    filename,
  })

  local git_args = { '-C', reponame }
  utils.list.concat(git_args, args)

  local lines, err = gitcli.run(git_args)
  if err then return nil, err end

  local result = {}
  local result_len = 0
  for i = 1, #lines do
    local line = lines[i]
    if vim.startswith(line, '@@') then
      result_len = result_len + 1
      result[result_len] = GitHunk(line)
    elseif result_len > 0 then
      result[result_len]:push(line)
    end
  end

  return result
end

return git_hunks
