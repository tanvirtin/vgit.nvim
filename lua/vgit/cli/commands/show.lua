local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local GitTree = lazy('vgit.git.GitTree')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local display_service = lazy('vgit.ui.display_service')

local show_command = {}

function show_command.parse_args(args)
  local opts = {
    commit = nil,
    flags = {},
  }

  for _, arg in ipairs(args) do
    if arg:match('^%-') then
      table.insert(opts.flags, arg)
    else
      -- First non-flag arg is the commit
      if not opts.commit then opts.commit = arg end
    end
  end

  -- Default to HEAD if no commit specified
  if not opts.commit then opts.commit = 'HEAD' end

  return opts
end

show_command.execute = event.async(function(args)
  args = args or {}

  local opts = show_command.parse_args(args)

  -- TODO: Implement flag support (e.g., --stat, --name-only)
  if #opts.flags > 0 then
    console.error('Show flags not implemented yet: ' .. table.concat(opts.flags, ', '))
    return
  end

  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local tree = GitTree(repo, opts.commit)

  -- Get commit info
  local commit, commit_err = tree:commit()
  if commit_err then
    console.error('Failed to get commit info: ' .. tostring(commit_err))
    return
  end

  -- Get list of files changed in this commit
  local files, files_err = tree:files()
  if files_err then
    console.error('Failed to get commit files: ' .. tostring(files_err))
    return
  end

  if not files or #files == 0 then
    console.info('No files changed in commit ' .. opts.commit)
    return
  end

  -- Get layout preference
  local layout_type = scene_setting:get('diff_preference') or 'unified'

  -- Get parent hash for diff comparison
  local EMPTY_TREE = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
  local parent_hash = commit.parent_hash or ''
  local from_ref = parent_hash ~= '' and parent_hash or EMPTY_TREE
  local to_ref = commit.commit_hash or commit.hash

  -- Build entries for ProjectDiffView (parallel)
  local funcs = {}
  for _, file in ipairs(files) do
    local filename = file.filename
    local file_old_filename = file.old_filename

    table.insert(funcs, function()
      local diff = repo:diff({
        type = 'range',
        filename = filename,
        old_filename = file_old_filename,
        from = from_ref,
        to = to_ref,
        layout_type = layout_type,
      })

      if not diff then return nil end

      local from_filename = file_old_filename or filename
      return {
        filename = filename,
        filetype = file.get_filetype and file:get_filetype() or 'text',
        diff = diff,
        status = file,
        original_lines = repo:file_lines(from_filename, from_ref) or {},
        current_lines = repo:file_lines(filename, to_ref) or {},
      }
    end)
  end

  local results = event.all(funcs)

  local entries = {}
  for i = 1, #funcs do
    if results[i] then table.insert(entries, results[i]) end
  end

  if #entries == 0 then
    console.info('No diffs available for commit ' .. opts.commit)
    return
  end

  -- Format commit info for display
  local commit_info = {
    hash = commit.commit_hash or commit.hash,
    author = commit.author,
    author_mail = commit.author_mail,
    author_time = commit.author_time,
    message = commit.message,
  }

  local data = {
    type = 'files',
    entries = {
      {
        title = string.format('Commit: %s', (commit_info.hash or ''):sub(1, 7)),
        entries = entries,
      },
    },
    layout_type = layout_type,
    commit_info = commit_info,
  }

  display_service.show_diff(data)
end)

return show_command
