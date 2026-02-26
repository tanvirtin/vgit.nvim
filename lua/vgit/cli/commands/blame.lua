local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local Buffer = lazy('vgit.core.Buffer')
local GitFile = lazy('vgit.git.GitFile')
local git_log = lazy('vgit.git.git_log')
local console = lazy('vgit.core.console')
local git_show = lazy('vgit.git.git_show')
local git_blame = lazy('vgit.git.git_blame')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local display_service = lazy('vgit.ui.display_service')

local blame_command = {}

local function normalize_file_path(filepath, repo_path)
  if not filepath or filepath == '' then return filepath end
  local absolute = vim.fn.fnamemodify(filepath, ':p')
  return fs.make_relative(repo_path, absolute)
end

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

local function execute_screen_blame(opts, repo, repo_path, filename)
  local filetype = fs.detect_filetype(filename)

  local blames, blame_err = git_blame.list(repo_path, filename)
  if blame_err then
    console.error(blame_err)
    return
  end

  if not blames or #blames == 0 then
    console.info('No blame information available')
    return
  end

  local lines, lines_err = git_show.lines(repo_path, filename, 'HEAD')
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
    reponame = repo_path,
    blames = blames,
    lines = lines,
  })
end

local function execute_lens_blame(opts, repo, repo_path, filename)
  local layout_type = scene_setting:get('diff_preference')
  local git_file = GitFile(filename)

  local blame, blame_err = git_file:blame(opts.line_number)
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
      filetype = git_file:get_filetype(),
      layout_type = layout_type,
      is_uncommitted = true,
    })
    return
  end

  local commit_hash = blame.hash or blame.commit_hash

  local log_result = git_log.get(repo:get_path(), commit_hash)
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
    filetype = git_file:get_filetype(),
    layout_type = layout_type,
    commit_hash = commit_hash,
    parent_hash = parent_hash,
    is_uncommitted = false,
  })
end

blame_command.execute = event.async(function(args)
  args = args or {}

  local opts = blame_command.parse_args(args)

  if #opts.flags > 0 then
    console.error('Blame flags not implemented yet (e.g., -w, -C, -M)')
    console.info('TODO: Support for git blame options')
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

  if not opts.line_number then opts.line_number = vim.api.nvim_win_get_cursor(0)[1] end

  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local repo_path = repo:get_path()
  local filename = normalize_file_path(opts.file, repo_path)

  if opts.screen then
    execute_screen_blame(opts, repo, repo_path, filename)
  else
    execute_lens_blame(opts, repo, repo_path, filename)
  end
end)

return blame_command
