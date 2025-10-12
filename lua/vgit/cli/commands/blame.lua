local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Buffer = require('vgit.core.Buffer')
local GitFile = require('vgit.git.GitFile')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')

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
    flags = {},
  }

  for _, arg in ipairs(args) do
    if arg:match('^%-') then
      -- Flag
      table.insert(opts.flags, arg)
    elseif arg:match('^%d+$') then
      -- Line number
      opts.line_number = tonumber(arg)
    else
      -- File path
      opts.file = arg
    end
  end

  return opts
end

blame_command.execute = loop.coroutine(function(args)
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

  local scene_setting = require('vgit.settings.scene')
  local layout_type = scene_setting:get('diff_preference')

  loop.free_textlock()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local repo_path = repo:get_path()
  local filename = normalize_file_path(opts.file, repo_path)

  loop.free_textlock()

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
    local data = {
      type = 'blame',
      blame = blame,
      filename = filename,
      line_number = opts.line_number,
      filetype = git_file:get_filetype(),
      layout_type = layout_type,
      is_uncommitted = true,
    }

    loop.free_textlock()
    local display_service = require('vgit.ui.display_service')
    display_service.show_blame(data)
    return
  end

  local commit_hash = blame.hash or blame.commit_hash

  loop.free_textlock()
  local git_log = require('vgit.git.git_log')
  local log_result = git_log.get(repo:get_path(), commit_hash)
  local parent_hash = log_result and log_result.parent_hash or commit_hash .. '^'

  loop.free_textlock()
  local diff = repo:diff({
    type = 'blame',
    filename = filename,
    blame_commit = commit_hash,
    parent_commit = parent_hash,
    layout_type = layout_type,
  })

  if not diff then
    console.error('Failed to generate blame diff')
    return
  end

  loop.free_textlock()

  local data = {
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
  }

  local display_service = require('vgit.ui.display_service')
  display_service.show_blame(data)
end)

return blame_command
