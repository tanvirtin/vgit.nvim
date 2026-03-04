local lazy = require('vgit.core.lazy')

local GitHunk = lazy('vgit.git.GitHunk')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_diff = {}

local function detect_filetype(filename)
  if not filename or filename == '' then return 'text' end
  return vim.filetype.match({ filename = filename }) or 'text'
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
      hunk = current_hunk,
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
      current_hunk = GitHunk(hunk_header)
    elseif current_hunk then
      local prefix = line:sub(1, 1)
      if prefix == '+' or prefix == '-' or prefix == ' ' then current_hunk:push(line) end
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
