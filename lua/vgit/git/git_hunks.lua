local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local utils = lazy('vgit.core.utils')
local gitcli = lazy('vgit.git.gitcli')
local GitHunk = lazy('vgit.git.GitHunk')
local console = lazy('vgit.core.console')
local git_setting = lazy('vgit.settings.git')

local git_hunks = {}

function git_hunks.live(reponame, original_lines, current_lines)
  local lines_limit = 5000
  local current_len = #current_lines

  if current_len > lines_limit then
    local temp_filename_a = fs.tmpname()
    local temp_filename_b = fs.tmpname()

    fs.write_file(temp_filename_a, original_lines)
    fs.write_file(temp_filename_b, current_lines)

    local ok, hunks, hunks_err = pcall(function()
      return git_hunks.list(reponame, { filenames = { temp_filename_a, temp_filename_b } })
    end)

    fs.remove_file(temp_filename_a)
    fs.remove_file(temp_filename_b)

    if not ok then
      console.debug.error(tostring(hunks))
      return nil, { tostring(hunks) }
    end
    return hunks, hunks_err
  end

  local o_lines_tbl = {}
  local c_lines_tbl = {}
  local original_len = #original_lines
  local num_lines = math.max(original_len, current_len)

  for i = 1, num_lines do
    local o_line = original_lines[i]
    local c_line = current_lines[i]

    if o_line then o_lines_tbl[#o_lines_tbl + 1] = o_line .. '\n' end
    if c_line then c_lines_tbl[#c_lines_tbl + 1] = c_line .. '\n' end
  end

  local live_hunks = {}

  vim.diff(table.concat(o_lines_tbl), table.concat(c_lines_tbl), {
    on_hunk = function(start_o, count_o, start_c, count_c)
      local hunk = GitHunk({ { start_o, count_o }, { start_c, count_c } })

      if count_o > 0 then
        for i = start_o, start_o + count_o - 1 do
          hunk.diff[#hunk.diff + 1] = '-' .. (original_lines[i] or '')
          hunk.stat.removed = hunk.stat.removed + 1
        end
      end

      if count_c > 0 then
        for i = start_c, start_c + count_c - 1 do
          hunk.diff[#hunk.diff + 1] = '+' .. (current_lines[i] or '')
          hunk.stat.added = hunk.stat.added + 1
        end
      end

      live_hunks[#live_hunks + 1] = hunk
    end,
    algorithm = git_setting:get('algorithm'),
  })

  return live_hunks
end

function git_hunks.custom(lines, opts)
  local diff = {}
  local line_count = #lines
  for i = 1, line_count do
    diff[i] = '+' .. lines[i]
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
