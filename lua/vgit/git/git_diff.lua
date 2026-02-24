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

local function parse_unified_diff(lines)
  local patch_entries = {}
  local current_filename = nil
  local current_filetype = 'text'
  local current_old_filename = nil
  local current_hunk = nil

  local function flush_hunk()
    if not current_hunk then return end
    if #current_hunk.diff > 0 then
      patch_entries[#patch_entries + 1] = {
        type = 'hunk',
        hunk = {
          header = current_hunk.header,
          diff = current_hunk.diff,
          top = current_hunk.top,
          bot = current_hunk.bot,
        },
        filetype = current_filetype,
        filename = current_filename,
      }
    end
    current_hunk = nil
  end

  for _, line in ipairs(lines) do
    local b_path = line:match('^diff %-%-git a/.+ b/(.+)$')
    if b_path then
      flush_hunk()
      current_filename = b_path
      current_old_filename = nil
      current_filetype = detect_filetype(b_path)
      patch_entries[#patch_entries + 1] = {
        type = 'file_header',
        filename = current_filename,
        filetype = current_filetype,
      }
    elseif line:match('^rename from (.+)$') then
      current_old_filename = line:match('^rename from (.+)$')
    elseif line:match('^rename to (.+)$') then
      local new_name = line:match('^rename to (.+)$')
      current_filename = new_name
      current_filetype = detect_filetype(new_name)
      for i = #patch_entries, 1, -1 do
        if patch_entries[i].type == 'file_header' then
          patch_entries[i].filename = (current_old_filename or new_name) .. ' -> ' .. new_name
          patch_entries[i].filetype = current_filetype
          break
        end
      end
    elseif line:match('^@@ ') then
      flush_hunk()
      local hunk_header = line:match('^(@@ .+ @@.*)$') or line
      local top, bot = parse_hunk_header_lnums(hunk_header)
      current_hunk = { header = hunk_header, diff = {}, top = top, bot = bot }
    elseif current_hunk then
      local prefix = line:sub(1, 1)
      if prefix == '+' or prefix == '-' or prefix == ' ' then current_hunk.diff[#current_hunk.diff + 1] = line end
    end
  end

  flush_hunk()

  local clean = {}
  for i, entry in ipairs(patch_entries) do
    if entry.type == 'file_header' then
      local next = patch_entries[i + 1]
      if next and next.type == 'hunk' then clean[#clean + 1] = entry end
    else
      clean[#clean + 1] = entry
    end
  end

  return clean
end

function git_diff.range_patch_entries(reponame, from_ref, to_ref)
  local result, err = GitQueryBuilder(reponame):diff():option('unified', 3):refs(from_ref, to_ref):execute()

  if err then return nil, err end
  if not result or #result == 0 then return {} end

  return parse_unified_diff(result)
end

function git_diff.staged_patch_entries(reponame)
  local result, err = GitQueryBuilder(reponame):diff():option('unified', 3):option('cached'):refs('HEAD'):execute()

  if err then return nil, err end
  if not result or #result == 0 then return {} end

  return parse_unified_diff(result)
end

function git_diff.unstaged_patch_entries(reponame)
  local result, err = GitQueryBuilder(reponame):diff():option('unified', 3):execute()

  if err then return nil, err end
  if not result or #result == 0 then return {} end

  return parse_unified_diff(result)
end

return git_diff
