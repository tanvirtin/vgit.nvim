local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local gitcli = require('vgit.git.git2.gitcli')

local Hunk = Object:extend()

function Hunk:generate_header(previous, current)
  return string.format('@@ -%s,%s +%s,%s @@', previous[1], previous[2], current[1], current[2])
end

function Hunk:parse_header(header)
  header = header or self.header
  local diffkey = vim.trim(vim.split(header, '@@', true)[2])
  local parsed_diffkey = vim.split(diffkey, ' ')
  local parsed_header = {}

  for i = 1, #parsed_diffkey do
    parsed_header[#parsed_header + 1] = vim.split(string.sub(parsed_diffkey[i], 2), ',')
  end

  local previous, current = parsed_header[1], parsed_header[2]

  previous[1] = tonumber(previous[1])
  previous[2] = tonumber(previous[2]) or 1
  current[1] = tonumber(current[1])
  current[2] = tonumber(current[2]) or 1

  return previous, current
end

function Hunk:parse_diff(diff)
  diff = diff or self.diff
  local removed_lines = {}
  local added_lines = {}

  for i = 1, #diff do
    local line = diff[i]
    local type = line:sub(1, 1)
    local cleaned_diff_line = line:sub(2, #line)

    if type == '+' then
      added_lines[#added_lines + 1] = cleaned_diff_line
    elseif type == '-' then
      removed_lines[#removed_lines + 1] = cleaned_diff_line
    end
  end

  return removed_lines, added_lines
end

function Hunk:constructor(header)
  local hunk = {
    header = nil,
    top = nil,
    bot = nil,
    type = nil,
    diff = {},
    stat = {
      added = 0,
      removed = 0,
    },
  }

  if not header then
    return hunk
  end

  local previous, current

  if type(header) == 'string' then
    previous, current = self:parse_header(header)
  else
    previous, current = unpack(header)
    header = self:generate_header(previous, current)
  end

  hunk.header = header
  hunk.top = current[1]
  hunk.bot = current[1] + current[2] - 1

  if current[2] == 0 then
    hunk.bot = hunk.top
    hunk.type = 'remove'
  elseif previous[2] == 0 then
    hunk.type = 'add'
  else
    hunk.type = 'change'
  end

  return hunk
end

function Hunk:push(line)
  local stat = self.stat
  local type = line:sub(1, 1)

  if type == '+' then
    stat.added = stat.added + 1
  elseif type == '-' then
    stat.removed = stat.removed + 1
  end

  local diff = self.diff

  diff[#diff + 1] = line

  return self
end

local hunks = { algorithm = 'myers' }

function hunks.live(original_lines, current_lines)
  local o_lines_str = ''
  local c_lines_str = ''
  local num_lines = math.max(#original_lines, #current_lines)

  for i = 1, num_lines do
    local o_line = original_lines[i]
    local c_line = current_lines[i]

    if o_line then
      o_lines_str = o_lines_str .. original_lines[i] .. '\n'
    end
    if c_line then
      c_lines_str = c_lines_str .. current_lines[i] .. '\n'
    end
  end

  local live_hunks = {}

  vim.diff(o_lines_str, c_lines_str, {
    on_hunk = function(start_o, count_o, start_c, count_c)
      local hunk = Hunk({ { start_o, count_o }, { start_c, count_c } })

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
    algorithm = 'myers',
  })

  return live_hunks
end

function hunks.custom(lines, opts)
  local diff = {}
  for i = 1, #lines do
    diff[#diff + 1] = string.format('+%s', lines[i])
  end

  local deleted = opts.deleted
  local untracked = opts.untracked

  local hunk = Hunk()
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

function hunks.list(reponame, filename, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local staged = opts.staged
  local unmerged = opts.unmerged
  local current = opts.current
  local parent = opts.parent
  local empty_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

  local args = {
    '-C',
    reponame,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', hunks.algorithm),
    '--patch-with-raw',
    '--unified=0',
  }

  if staged == true then
    utils.list.concat(args, { '--cached' })
  end

  if unmerged == true then
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
      result[#result + 1] = Hunk(line)
    else
      if #result > 0 then
        local hunk = result[#result]
        hunk:push(line)
      end
    end
  end

  return result, err
end

return hunks
