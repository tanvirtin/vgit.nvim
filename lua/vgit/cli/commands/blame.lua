local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local Buffer = lazy('vgit.core.Buffer')
local Window = lazy('vgit.core.Window')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local display_service = lazy('vgit.ui.display_service')
local normalize_file_path = require('vgit.cli.commands.normalize_file_path')

local blame_command = {}

function blame_command.parse_args(args)
  local opts = {
    file = nil,
    line_number = nil,
    screen = false,
    flags = {},
  }

  for _, arg in ipairs(args) do
    if arg == '--screen' then
      opts.screen = true
    elseif arg:match('^%-') then
      table.insert(opts.flags, arg)
    elseif arg:match('^%d+$') then
      opts.line_number = tonumber(arg)
    else
      opts.file = arg
    end
  end

  return opts
end

local function execute_screen_blame(opts, repo, filename)
  local filetype = fs.detect_filetype(filename)

  local blames, blame_err = repo:blame_list(filename)
  if blame_err then
    console.error(blame_err)
    return
  end

  if not blames or #blames == 0 then
    console.info('No blame information available')
    return
  end

  local lines, lines_err = repo:file_lines(filename, 'HEAD')
  if lines_err or not lines then
    local buffer = Buffer(0)
    lines = buffer:get_lines()

    if not lines or #lines == 0 then
      console.error('Failed to get file content')
      return
    end
  end

  display_service.show_blame_view({
    filename = filename,
    filetype = filetype,
    reponame = repo:get_path(),
    blames = blames,
    lines = lines,
  })
end

local function execute_lens_blame(opts, repo, filename)
  local layout_type = scene_setting:get('diff_preference') or 'unified'
  local filetype = fs.detect_filetype(filename)

  local blame, blame_err = repo:blame_file(filename, opts.line_number)
  if blame_err then
    console.error(blame_err)
    return
  end

  if not blame then
    console.error('Failed to get blame information for line ' .. opts.line_number)
    return
  end

  if blame:is_uncommitted() then
    display_service.show_blame({
      type = 'blame',
      blame = blame,
      filename = filename,
      line_number = opts.line_number,
      filetype = filetype,
      layout_type = layout_type,
      is_uncommitted = true,
    })
    return
  end

  local commit_hash = blame.hash or blame.commit_hash

  local log_result = repo:log_get(commit_hash)
  local parent_hash = log_result and log_result.parent_hash or commit_hash .. '^'

  local diff = repo:diff({
    type = 'blame',
    filename = blame.filename or filename,
    old_filename = blame.old_filename,
    blame_commit = commit_hash,
    parent_commit = parent_hash,
    layout_type = layout_type,
  })

  if not diff then
    console.error('Failed to generate blame diff')
    return
  end

  display_service.show_blame({
    type = 'blame',
    blame = blame,
    filename = filename,
    line_number = opts.line_number,
    diff = diff,
    filetype = filetype,
    layout_type = layout_type,
    commit_hash = commit_hash,
    parent_hash = parent_hash,
    is_uncommitted = false,
  })
end

blame_command.execute = event.async(function(args)
  args = args or {}

  local opts = blame_command.parse_args(args)

  -- TODO: Support for git blame options (e.g., -w, -C, -M)
  if #opts.flags > 0 then
    console.info('Flag options not yet supported')
    return
  end

  if not opts.file then
    local buffer = Buffer(0)
    opts.file = buffer:get_name()

    if not opts.file or opts.file == '' then
      console.error('Not in a file buffer')
      return
    end
  end

  if not opts.line_number then
    local win = Window(0)
    opts.line_number = win:get_cursor()[1]
  end

  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local filename = normalize_file_path(opts.file, repo:get_path())

  if opts.screen then
    execute_screen_blame(opts, repo, filename)
  else
    execute_lens_blame(opts, repo, filename)
  end
end)

return blame_command
