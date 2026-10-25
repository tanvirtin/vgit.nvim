local lazy = require('vgit.core.lazy')

local GitHunk = lazy('vgit.git.GitHunk')

local engine = {}

local function make_hunk(original_lines, current_lines, start_o, count_o, start_c, count_c)
  local hunk = GitHunk({ { start_o, count_o }, { start_c, count_c } })

  for i = start_o, start_o + count_o - 1 do
    hunk.diff[#hunk.diff + 1] = '-' .. (original_lines[i] or '')
    hunk.stat.removed = hunk.stat.removed + 1
  end

  for i = start_c, start_c + count_c - 1 do
    hunk.diff[#hunk.diff + 1] = '+' .. (current_lines[i] or '')
    hunk.stat.added = hunk.stat.added + 1
  end

  return hunk
end

local function vim_live(original_lines, current_lines, opts)
  local o_lines, c_lines = {}, {}
  local num_lines = math.max(#original_lines, #current_lines)

  for i = 1, num_lines do
    local o_line, c_line = original_lines[i], current_lines[i]

    if o_line then o_lines[#o_lines + 1] = o_line .. '\n' end
    if c_line then c_lines[#c_lines + 1] = c_line .. '\n' end
  end

  local hunks = {}

  vim.diff(table.concat(o_lines), table.concat(c_lines), {
    on_hunk = function(start_o, count_o, start_c, count_c)
      hunks[#hunks + 1] = make_hunk(original_lines, current_lines, start_o, count_o, start_c, count_c)
    end,
    algorithm = opts.algorithm or 'myers',
  })

  return hunks
end

local function backtrack(trace, a, b, distance)
  local x, y = #a, #b
  local ops = {}

  for step = distance, 1, -1 do
    local v = trace[step + 1]
    local k = x - y
    local prev_k

    if k == -step or (k ~= step and (v[k - 1] or -1) < (v[k + 1] or -1)) then
      prev_k = k + 1
    else
      prev_k = k - 1
    end

    local prev_x = v[prev_k] or 0
    local prev_y = prev_x - prev_k

    while x > prev_x and y > prev_y do
      ops[#ops + 1] = { 'equal', a[x] }
      x = x - 1
      y = y - 1
    end

    if x == prev_x then
      ops[#ops + 1] = { 'insert', b[y] }
    else
      ops[#ops + 1] = { 'delete', a[x] }
    end

    x, y = prev_x, prev_y
  end

  while x > 0 and y > 0 do
    ops[#ops + 1] = { 'equal', a[x] }
    x = x - 1
    y = y - 1
  end

  while x > 0 do
    ops[#ops + 1] = { 'delete', a[x] }
    x = x - 1
  end

  while y > 0 do
    ops[#ops + 1] = { 'insert', b[y] }
    y = y - 1
  end

  local result = {}

  for i = #ops, 1, -1 do
    result[#result + 1] = ops[i]
  end

  return result
end

local function myers(a, b)
  local n, m = #a, #b
  local max = n + m
  local v = { [1] = 0 }
  local trace = {}

  for distance = 0, max do
    trace[distance + 1] = {}

    for k, x in pairs(v) do
      trace[distance + 1][k] = x
    end

    for k = -distance, distance, 2 do
      local x

      if k == -distance or (k ~= distance and (v[k - 1] or -1) < (v[k + 1] or -1)) then
        x = v[k + 1] or 0
      else
        x = (v[k - 1] or 0) + 1
      end

      local y = x - k

      while x < n and y < m and a[x + 1] == b[y + 1] do
        x = x + 1
        y = y + 1
      end

      v[k] = x

      if x >= n and y >= m then return backtrack(trace, a, b, distance) end
    end
  end
end

local function lua_live(original_lines, current_lines)
  local ops = myers(original_lines, current_lines)
  local hunks = {}
  local old_idx, new_idx, i = 1, 1, 1

  while i <= #ops do
    if ops[i][1] == 'equal' then
      old_idx = old_idx + 1
      new_idx = new_idx + 1
      i = i + 1
    else
      local start_o, start_c = old_idx, new_idx
      local removes, adds = {}, {}

      while i <= #ops and ops[i][1] ~= 'equal' do
        local op, line = ops[i][1], ops[i][2]

        if op == 'delete' then
          removes[#removes + 1] = line
          old_idx = old_idx + 1
        else
          adds[#adds + 1] = line
          new_idx = new_idx + 1
        end

        i = i + 1
      end

      local count_o, count_c = #removes, #adds
      local start_old = count_o > 0 and start_o or start_o - 1
      local start_new = count_c > 0 and start_c or start_c - 1
      local hunk = GitHunk({ { start_old, count_o }, { start_new, count_c } })

      for _, line in ipairs(removes) do
        hunk.diff[#hunk.diff + 1] = '-' .. line
        hunk.stat.removed = hunk.stat.removed + 1
      end

      for _, line in ipairs(adds) do
        hunk.diff[#hunk.diff + 1] = '+' .. line
        hunk.stat.added = hunk.stat.added + 1
      end

      hunks[#hunks + 1] = hunk
    end
  end

  return hunks
end

function engine.live(original_lines, current_lines, opts)
  opts = opts or {}

  local has_vim_diff = type(vim) == 'table' and type(vim.diff) == 'function'

  if opts.engine ~= 'lua' and has_vim_diff then return vim_live(original_lines, current_lines, opts) end

  return lua_live(original_lines, current_lines)
end

function engine.custom(lines, opts)
  opts = opts or {}

  local diff = {}
  local prefix = opts.deleted and '-' or '+'

  for i = 1, #lines do
    diff[i] = prefix .. lines[i]
  end

  local hunk = GitHunk()

  if opts.untracked then
    hunk.type = 'add'
    hunk.stat = { added = #lines, removed = 0 }
    hunk.header = hunk:generate_header({ 0, 0 }, { 1, #lines })
  elseif opts.deleted then
    hunk.type = 'remove'
    hunk.stat = { added = 0, removed = #lines }
    hunk.header = hunk:generate_header({ 1, #lines }, { 0, 0 })
  end

  hunk.top = 1
  hunk.bot = #lines
  hunk.diff = diff

  return { hunk }
end

return engine
