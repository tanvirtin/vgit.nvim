local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local display_service = lazy('vgit.ui.display_service')

local worktree_command = {}

function worktree_command.parse_args(args)
  local opts = { action = 'screen', path = nil, branch = nil }
  if not args or #args == 0 then return opts end

  local first = args[1]

  if first == 'add' then
    opts.action = 'add'
    opts.path = args[2]
    opts.branch = args[3]
  elseif first == 'remove' then
    opts.action = 'remove'
    opts.path = args[2]
  elseif first == 'switch' then
    opts.action = 'switch'
    opts.path = args[2]
  end

  return opts
end

worktree_command.execute = event.async(function(args)
  args = args or {}
  local opts = worktree_command.parse_args(args)

  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  if opts.action == 'add' then
    if not opts.path then
      console.error('Path is required: VGit worktree add <path> [branch]')
      return
    end
    local add_opts = {}
    if opts.branch then add_opts.branch = opts.branch end
    local _, err = repo:worktree_add(opts.path, add_opts)
    if err then
      console.error(err[1] or tostring(err))
      return
    end
    console.info('Worktree created: ' .. opts.path)
    return
  end

  if opts.action == 'remove' then
    if not opts.path then
      console.error('Path is required: VGit worktree remove <path>')
      return
    end
    local _, err = repo:worktree_remove(opts.path)
    if err then
      console.error(err[1] or tostring(err))
      return
    end
    console.info('Worktree removed: ' .. opts.path)
    return
  end

  if opts.action == 'switch' then
    if not opts.path then
      console.error('Path is required: VGit worktree switch <path>')
      return
    end
    vim.cmd('cd ' .. vim.fn.fnameescape(opts.path))
    console.info('Switched to worktree: ' .. opts.path)
    return
  end

  -- Default: show worktree screen
  local worktrees, list_err = repo:worktree_list()
  if list_err then
    console.error(list_err[1] or tostring(list_err))
    return
  end

  if not worktrees or #worktrees == 0 then
    console.info('No worktrees found')
    return
  end

  display_service.show_worktree({
    worktrees = worktrees,
    repo = repo,
  })
end)

return worktree_command
