local event = require('vgit.core.event')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')
local GitTree = require('vgit.git.GitTree')

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
      if not opts.commit then
        opts.commit = arg
      end
    end
  end

  -- Default to HEAD if no commit specified
  if not opts.commit then
    opts.commit = 'HEAD'
  end

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

  event.await()

  local tree = GitTree(repo, opts.commit)

  -- Get commit info
  local commit, commit_err = tree:commit()
  if commit_err then
    console.error('Failed to get commit info: ' .. tostring(commit_err))
    return
  end

  event.await()

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

  event.await()

  -- Get layout preference
  local scene_setting = require('vgit.settings.scene')
  local layout_type = scene_setting:get('diff_preference') or 'unified'

  -- Get parent hash for diff comparison
  local parent_hash = commit.parent_hash or ''

  -- Build entries for ProjectDiffView
  local entries = {}
  for _, file in ipairs(files) do
    local filename = file.filename

    event.await()

    -- Get diff for this file
    local diff = repo:diff({
      type = 'range',
      filename = filename,
      from = parent_hash ~= '' and parent_hash or nil,
      to = commit.commit_hash or commit.hash,
      layout_type = layout_type,
    })

    if diff then
      table.insert(entries, {
        filename = filename,
        filetype = file.get_filetype and file:get_filetype() or 'text',
        diff = diff,
        status = file,
      })
    end
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

  local display_service = require('vgit.ui.display_service')
  display_service.show_diff(data)
end)

return show_command
