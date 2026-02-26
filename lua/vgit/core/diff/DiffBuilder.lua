local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local Object = lazy('vgit.core.Object')
local assertion = lazy('vgit.core.assertion')
local git_conflict = lazy('vgit.git.git_conflict')
local LiveHunkGenerator = lazy('vgit.core.diff.hunks.LiveHunkGenerator')
local DiffLayoutGenerator = lazy('vgit.core.diff.layout.DiffLayoutGenerator')

local DiffBuilder = Object:extend()

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
  self._repository = repository
end

function DiffBuilder:_get_blame_lines(spec)
  local blame_commit = spec.blame_commit
  local parent_commit = spec.parent_commit
  local filename = spec.filename
  local old_filename = spec.old_filename

  assertion.assert(blame_commit, 'blame_commit is required').assert(filename, 'filename is required')

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
  spec = spec or {}
  local type = spec.type
  local filename = spec.filename
  local blame_commit = spec.blame_commit

  assertion.assert(spec, 'spec is required').assert(type, 'type is required').assert(filename, 'filename is required')

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

function DiffBuilder:_get_metadata(spec)
  spec = spec or {}
  local type = spec.type
  local filename = spec.filename
  local blame_commit = spec.blame_commit
  local parent_commit = spec.parent_commit
  local from = spec.from
  local to = spec.to

  assertion.assert(type, 'type is required').assert(filename, 'filename is required')

  if type == 'blame' then
    return {
      comparison_mode = 'blame',
      blamed_commit = blame_commit,
      base_ref = parent_commit or blame_commit .. '~1',
      current_ref = blame_commit,
      filename = filename,
    }
  elseif type == 'range' then
    return {
      comparison_mode = 'range',
      from = from or 'HEAD~1',
      to = to or 'HEAD',
      filename = filename,
    }
  elseif type == 'conflict' then
    return {
      comparison_mode = 'conflict',
      filename = filename,
      is_unmerged = true,
    }
  end

  return {}
end

function DiffBuilder:_build_conflict_diff(spec)
  spec = spec or {}
  local layout_type = spec.layout_type or 'unified'

  local _, conflict_lines = self:_get_lines(spec)
  assertion.assert(conflict_lines, 'failed to retrieve conflict lines')

  local conflicts = git_conflict.parse(conflict_lines)

  local layout_generator = DiffLayoutGenerator()
  local diff = layout_generator:generate({}, conflict_lines, {
    layout_type = layout_type,
    conflict = conflicts,
    metadata = self:_get_metadata(spec),
  })

  return diff
end

function DiffBuilder:build(spec)
  spec = spec or {}
  local type = spec.type
  local hunk_generator = spec.hunk_generator or LiveHunkGenerator()
  local layout_type = spec.layout_type or 'unified'

  assertion.assert(spec, 'spec is required').assert(type, 'type is required')

  if fs.is_dir(spec.filename) then return end
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
    or hunk_generator:generate(original_lines, current_lines, spec)
  assertion.assert(hunks, 'hunk generator returned nil')

  local layout_generator = DiffLayoutGenerator()
  local diff = layout_generator:generate(hunks, display_lines, {
    layout_type = layout_type,
    original_lines = original_lines,
    is_deleted = is_deleted,
    metadata = self:_get_metadata(spec),
  })

  return diff
end

return DiffBuilder
