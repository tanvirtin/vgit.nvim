local utils = require('vgit.core.utils')
local gitcli = require('vgit.git.gitcli')
local GitHunk = require('vgit.git.GitHunk')

local git_hunks = { algorithm = 'myers' }

function git_hunks.live(original_lines, current_lines)
  local o_lines_tbl = {}
  local c_lines_tbl = {}
  local num_lines = math.max(#original_lines, #current_lines)

  for i = 1, num_lines do
    local o_line = original_lines[i]
    local c_line = current_lines[i]

    if o_line then o_lines_tbl[#o_lines_tbl + 1] = table.concat({ original_lines[i], '\n' }) end
    if c_line then c_lines_tbl[#c_lines_tbl + 1] = table.concat({ current_lines[i], '\n' }) end
  end

  local live_hunks = {}

  vim.diff(table.concat(o_lines_tbl), table.concat(c_lines_tbl), {
    on_hunk = function(start_o, count_o, start_c, count_c)
      local hunk = GitHunk({ { start_o, count_o }, { start_c, count_c } })

      if count_o > 0 then
        for i = start_o, start_o + count_o - 1 do
          hunk.diff[#hunk.diff + 1] = table.concat({ '-', (original_lines[i] or '') })
          hunk.stat.removed = hunk.stat.removed + 1
        end
      end

      if count_c > 0 then
        for i = start_c, start_c + count_c - 1 do
          hunk.diff[#hunk.diff + 1] = table.concat({ '+', (current_lines[i] or '') })
          hunk.stat.added = hunk.stat.added + 1
        end
      end

      live_hunks[#live_hunks + 1] = hunk
    end,
    algorithm = git_hunks.algorithm,
  })

  return live_hunks
end

function git_hunks.custom(lines, opts)
  local diff = {}
  for i = 1, #lines do
    diff[#diff + 1] = string.format('+%s', lines[i])
  end

  local deleted = opts.deleted
  local untracked = opts.untracked

  local hunk = GitHunk()

  if untracked then
    hunk.type = 'add'
    hunk.stat = { added = #lines, removed = 0 }
    hunk.header = hunk:generate_header({ 0, 0 }, { 1, #lines })
  elseif deleted then
    hunk.type = 'remove'
    hunk.stat = { added = 0, removed = #lines }
    hunk.header = hunk:generate_header({ 1, #lines }, { 0, 0 })
  end

  hunk.top = 1
  hunk.bot = #lines
  hunk.diff = diff

  return { hunk }
end

function git_hunks.list(reponame, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local staged = opts.staged
  local unmerged = opts.unmerged
  local current = opts.current
  local parent = opts.parent
  local filename = opts.filename
  local empty_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

  local filenames = opts.filenames
  if filenames and #filenames ~= 2 then error('incorrect number of files provided') end

  local args = {
    '-C',
    reponame,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', git_hunks.algorithm),
    '--patch-with-raw',
    '--unified=0',
  }

  if staged == true then utils.list.concat(args, { '--cached' }) end
  if filenames then
    utils.list.concat(args, { '--no-index' }, filenames)
  elseif unmerged == true then
    if not parent then return nil, { 'parent is required' } end
    if not current then return nil, { 'current is required' } end

    utils.list.concat(args, {
      string.format('%s:%s', current, filename),
      string.format('%s:%s', parent, filename),
    })
  elseif parent and current then
    utils.list.concat(args, {
      #parent > 0 and parent or empty_hash,
      current,
    })
  elseif parent and not current then
    utils.list.concat(args, { parent })
  end

  utils.list.concat(args, {
    '--',
    filename,
  })

  local lines, err = gitcli.run(args)

  local result = {}
  for i = 1, #lines do
    local line = lines[i]
    if vim.startswith(line, '@@') then
      result[#result + 1] = GitHunk(line)
    else
      if #result > 0 then
        local hunk = result[#result]
        hunk:push(line)
      end
    end
  end

  return result, err
end

return git_hunks
