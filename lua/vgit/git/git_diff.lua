local lazy = require('vgit.core.lazy')

local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_diff = {}

local function detect_filetype(filename)
  if not filename or filename == '' then return 'text' end
  return vim.filetype.match({ filename = filename }) or 'text'
end

local function parse_hunk_header_lnums(header)
  local new_start, new_count = header:match('^@@ %-%d+[,%d]* %+(%d+),?(%d*)')
  new_start = tonumber(new_start) or 1
  new_count = tonumber(new_count)
  if new_count == nil then new_count = 1 end
  return new_start, new_start + math.max(new_count - 1, 0)
end

local function parse_hunk_entries(lines)
  local entries = {}
  local filename, filetype, old_filename
  local current_hunk
  local file_header

  local function flush_hunk()
    if not current_hunk or #current_hunk.diff == 0 then
      current_hunk = nil
      return
    end

    if file_header then
      entries[#entries + 1] = file_header
      file_header = nil
    end

    entries[#entries + 1] = {
      type = 'hunk',
      hunk = {
        header = current_hunk.header,
        diff = current_hunk.diff,
        top = current_hunk.top,
        bot = current_hunk.bot,
      },
      filetype = filetype,
      filename = filename,
    }
    current_hunk = nil
  end

  for _, line in ipairs(lines) do
    local b_path = line:match('^diff %-%-git a/.+ b/(.+)$')
    if b_path then
      flush_hunk()
      filename = b_path
      old_filename = nil
      filetype = detect_filetype(b_path)
      file_header = {
        type = 'file_header',
        filename = filename,
        filetype = filetype,
      }
    elseif line:match('^rename from ') then
      old_filename = line:match('^rename from (.+)$')
    elseif line:match('^rename to ') then
      local new_name = line:match('^rename to (.+)$')
      filename = new_name
      filetype = detect_filetype(new_name)
      if file_header then
        file_header.filename = (old_filename or new_name) .. ' -> ' .. new_name
        file_header.filetype = filetype
      end
    elseif line:match('^@@ ') then
      flush_hunk()
      local hunk_header = line:match('^(@@ .+ @@.*)$') or line
      local top, bot = parse_hunk_header_lnums(hunk_header)
      current_hunk = { header = hunk_header, diff = {}, top = top, bot = bot }
    elseif current_hunk then
      local prefix = line:sub(1, 1)
      if prefix == '+' or prefix == '-' or prefix == ' ' then
        current_hunk.diff[#current_hunk.diff + 1] = line
      end
    end
  end

  flush_hunk()

  return entries
end

local function run_diff(builder)
  local result, err = builder:execute()

  if err then return nil, err end
  if not result or #result == 0 then return {} end

  return parse_hunk_entries(result)
end

function git_diff.range_hunk_entries(reponame, from_ref, to_ref)
  return run_diff(GitQueryBuilder(reponame):diff():option('unified', 3):refs(from_ref, to_ref))
end

function git_diff.staged_hunk_entries(reponame)
  return run_diff(GitQueryBuilder(reponame):diff():option('unified', 3):option('cached'):refs('HEAD'))
end

function git_diff.unstaged_hunk_entries(reponame)
  return run_diff(GitQueryBuilder(reponame):diff():option('unified', 3))
end

return git_diff
