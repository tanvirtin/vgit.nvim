local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local assertion = lazy('vgit.core.assertion')
local git_diff = lazy('vgit.git.git_diff')
local GitHunk = lazy('vgit.git.GitHunk')
local git_conflict = lazy('vgit.git.git_conflict')
local Diff = lazy('vgit.core.diff.Diff')
local git_hunks = lazy('vgit.git.git_hunks')

local DiffBuilder = Object:extend()

local function split_raw_hunk(raw_hunk)
  local header = raw_hunk.header
  local _, current = GitHunk.parse_header(GitHunk, header)
  local old_pos = tonumber(header:match('@@ %-(%d+)')) or 1
  local new_pos = current[1]

  local hunks = {}
  local pending_removes = {}
  local pending_adds = {}
  local remove_start_old = nil
  local add_start_new = nil

  local function flush()
    local has_removes = #pending_removes > 0
    local has_adds = #pending_adds > 0
    if not has_removes and not has_adds then return end

    local h_old_start, h_new_start
    local h_old_count = #pending_removes
    local h_new_count = #pending_adds

    if has_removes and has_adds then
      h_old_start = remove_start_old
      h_new_start = add_start_new
    elseif has_removes then
      h_old_start = remove_start_old
      h_new_start = new_pos - 1
    else
      h_old_start = math.max(0, old_pos - 1)
      h_new_start = add_start_new
    end

    local header_str = string.format('@@ -%s,%s +%s,%s @@', h_old_start, h_old_count, h_new_start, h_new_count)
    local git_hunk = GitHunk(header_str)
    for _, line in ipairs(pending_removes) do
      git_hunk:push(line)
    end
    for _, line in ipairs(pending_adds) do
      git_hunk:push(line)
    end
    hunks[#hunks + 1] = git_hunk

    pending_removes = {}
    pending_adds = {}
    remove_start_old = nil
    add_start_new = nil
  end

  for _, line in ipairs(raw_hunk.diff) do
    local prefix = line:sub(1, 1)
    if prefix == '-' then
      if #pending_adds > 0 and #pending_removes == 0 then flush() end
      if not remove_start_old then remove_start_old = old_pos end
      pending_removes[#pending_removes + 1] = line
      old_pos = old_pos + 1
    elseif prefix == '+' then
      if not add_start_new then add_start_new = new_pos end
      pending_adds[#pending_adds + 1] = line
      new_pos = new_pos + 1
    else
      flush()
      old_pos = old_pos + 1
      new_pos = new_pos + 1
    end
  end

  flush()
  return hunks
end

local function group_entries_by_file(entries)
  local files = {}
  local current_file = nil

  for _, entry in ipairs(entries) do
    if entry.type == 'file_header' then
      local new_name = entry.filename:match('^.+ %-> (.+)$') or entry.filename
      local old_name = entry.filename:match('^(.+) %-> .+$') or entry.filename
      current_file = {
        display_name = entry.filename,
        filename = new_name,
        old_filename = (old_name ~= new_name) and old_name or nil,
        filetype = entry.filetype,
        raw_hunks = {},
      }
      files[#files + 1] = current_file
    elseif entry.type == 'hunk' and current_file then
      current_file.raw_hunks[#current_file.raw_hunks + 1] = entry.hunk
    end
  end

  return files
end

local function has_binary_content(lines)
  if not lines then return false end
  for i = 1, math.min(#lines, 100) do
    local line = lines[i]
    -- Check for NUL bytes (git show preserves them) and embedded newlines
    -- (vim.fn.readfile converts NUL to \n in text mode)
    if line:find('\0', 1, true) or line:find('\n', 1, true) then return true end
  end
  return false
end

function DiffBuilder:constructor(repository)
  return {
    ['$_repository'] = repository,
  }
end

function DiffBuilder:_get_blame_lines(spec)
  local blame_commit = spec.blame_commit
  local parent_commit = spec.parent_commit
  local filename = spec.filename
  local old_filename = spec.old_filename

  local effective_parent_commit = parent_commit or blame_commit .. '~1'

  local original_lines = self._repository:file_lines(old_filename or filename, effective_parent_commit)
  local current_lines = self._repository:file_lines(filename, blame_commit)

  return original_lines, current_lines
end

function DiffBuilder:_get_range_lines(spec)
  local from = spec.from or 'HEAD~1'
  local to = spec.to or 'HEAD'
  local filename = spec.filename
  local old_filename = spec.old_filename

  assertion.assert(filename, 'filename is required')

  local original_lines = self._repository:file_lines(old_filename or filename, from)
  local current_lines

  if to == 'disk' then
    local repo_path = self._repository:get_path()
    local full_path = fs.absolute_path(repo_path, filename)
    current_lines = fs.read_file(full_path)
  else
    current_lines = self._repository:file_lines(filename, to)
  end

  return original_lines, current_lines
end

function DiffBuilder:_get_conflict_lines(spec)
  local filename = spec.filename

  assertion.assert(filename, 'filename is required')

  local repo_path = self._repository:get_path()
  local full_path = fs.absolute_path(repo_path, filename)
  local conflict_lines = fs.read_file(full_path)

  assertion.assert(conflict_lines, 'failed to read conflict file: ' .. full_path)

  return nil, conflict_lines
end

function DiffBuilder:_get_lines(spec)
  local type = spec.type
  local filename = spec.filename
  local blame_commit = spec.blame_commit

  assertion.assert(type, 'type is required').assert(filename, 'filename is required')

  if type == 'blame' then
    assertion.assert(blame_commit, 'blame_commit is required for blame type')
    return self:_get_blame_lines(spec)
  elseif type == 'range' then
    return self:_get_range_lines(spec)
  elseif type == 'conflict' then
    return self:_get_conflict_lines(spec)
  else
    assertion.assert(false, 'unknown diff type: ' .. type)
  end
end

function DiffBuilder:_build_conflict_diff(spec)
  local layout_type = spec.layout_type or 'unified'

  local _, conflict_lines = self:_get_lines(spec)
  assertion.assert(conflict_lines, 'failed to retrieve conflict lines')

  local conflicts = git_conflict.parse(conflict_lines)

  local diff = Diff():generate({}, conflict_lines, layout_type, {
    conflicts = conflicts,
  })

  return diff
end

function DiffBuilder:_build_multi_file_diff(spec)
  local repo_path = self._repository:get_path()
  local from = spec.from
  local to = spec.to

  if from == 'HEAD' and to == 'index' then
    return git_diff.staged_hunk_entries(repo_path)
  elseif to == 'disk' then
    return git_diff.unstaged_hunk_entries(repo_path)
  else
    return git_diff.range_hunk_entries(repo_path, from, to)
  end
end

function DiffBuilder:build_multi_file_diffs(spec)
  local raw_entries, err = self:_build_multi_file_diff(spec)
  if err then return nil, err end
  if not raw_entries or #raw_entries == 0 then return {} end

  local layout_type = spec.layout_type or 'unified'
  local grouped_files = group_entries_by_file(raw_entries)

  local build_funcs = {}
  for _, fg in ipairs(grouped_files) do
    local file_group = fg
    build_funcs[#build_funcs + 1] = function()
      local file_hunks = {}
      for _, raw_hunk in ipairs(file_group.raw_hunks) do
        local sub_hunks = split_raw_hunk(raw_hunk)
        for _, h in ipairs(sub_hunks) do
          file_hunks[#file_hunks + 1] = h
        end
      end

      if #file_hunks == 0 then return nil end

      -- Always try to fetch the target-side content first
      local display_lines, original_lines, current_lines
      if spec.to == 'disk' then
        local repo_path = self._repository:get_path()
        current_lines = fs.read_file(fs.absolute_path(repo_path, file_group.filename))
      else
        current_lines = self._repository:file_lines(file_group.filename, spec.to or 'HEAD')
      end

      -- File is truly deleted only when it doesn't exist on the target side
      local is_deleted = not current_lines
      if is_deleted then
        local all_removes = true
        for _, hunk in ipairs(file_hunks) do
          if hunk.type ~= 'remove' then
            all_removes = false
            break
          end
        end
        if not all_removes then is_deleted = false end
      end

      if is_deleted then
        original_lines =
          self._repository:file_lines(file_group.old_filename or file_group.filename, spec.from or 'HEAD')
        if not original_lines or has_binary_content(original_lines) then return nil end
        current_lines = {}
        display_lines = original_lines
      else
        if not current_lines then current_lines = {} end
        if has_binary_content(current_lines) then return nil end
        original_lines = {}
        display_lines = current_lines
      end

      local diff = Diff():generate(file_hunks, display_lines, layout_type, {
        is_deleted = is_deleted,
      })

      return {
        filename = file_group.display_name,
        filetype = file_group.filetype,
        original_lines = original_lines,
        current_lines = current_lines,
        diff = diff,
      }
    end
  end

  local results = event.all(build_funcs)

  local file_diffs = {}
  for _, result in ipairs(results) do
    if result then file_diffs[#file_diffs + 1] = result end
  end

  return file_diffs
end

function DiffBuilder:build(spec)
  local type = spec.type
  local layout_type = spec.layout_type or 'unified'

  assertion.assert(type, 'type is required')

  if not spec.filename then return self:build_multi_file_diffs(spec) end

  if fs.is_dir(fs.absolute_path(self._repository:get_path(), spec.filename)) then return end
  if type == 'conflict' then return self:_build_conflict_diff(spec) end

  local original_lines, current_lines = self:_get_lines(spec)

  if has_binary_content(original_lines) or has_binary_content(current_lines) then return end

  local is_deleted = false
  local display_lines = current_lines

  if not original_lines and not current_lines then
    return
  elseif not original_lines and current_lines then
    original_lines = {}
  elseif original_lines and not current_lines then
    current_lines = {}
    is_deleted = true
    display_lines = original_lines
  end

  local hunks = (spec.hunks and #spec.hunks > 0) and spec.hunks
    or git_hunks.live(self._repository:get_path(), original_lines, current_lines)
  assertion.assert(hunks, 'hunk generator returned nil')

  local diff = Diff():generate(hunks, display_lines, layout_type, {
    is_deleted = is_deleted,
  })

  return diff
end

return DiffBuilder
