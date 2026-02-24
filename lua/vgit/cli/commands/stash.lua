local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local git_stash = lazy('vgit.git.git_stash')
local repository = lazy('vgit.git.repository')
local display_service = lazy('vgit.ui.display_service')

local stash_command = {}

local function parse_args(args)
  local opts = { action = 'screen', index = nil }
  if not args or #args == 0 then return opts end

  local first = args[1]

  if first == 'add' then
    opts.action = 'add'
  elseif first == 'pop' then
    opts.action = 'pop'
    opts.index = args[2] and tonumber(args[2]) or 0
  elseif first == 'apply' then
    opts.action = 'apply'
    opts.index = args[2] and tonumber(args[2]) or 0
  elseif first == 'drop' then
    opts.action = 'drop'
    opts.index = args[2] and tonumber(args[2]) or 0
  elseif first == 'clear' then
    opts.action = 'clear'
  end

  return opts
end

stash_command.execute = event.async(function(args)
  args = args or {}
  local opts = parse_args(args)

  event.await()

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local repo_path = repo:get_path()

  if opts.action == 'add' then
    local _, err = git_stash.add(repo_path)
    if err then
      console.error(err[1] or tostring(err))
      return
    end
    console.info('Changes stashed')
    return
  end

  if opts.action == 'pop' then
    local stash_ref = string.format('stash@{%d}', opts.index)
    local _, err = git_stash.pop(repo_path, stash_ref)
    if err then
      console.error(err[1] or tostring(err))
      return
    end
    console.info('Stash popped: ' .. stash_ref)
    return
  end

  if opts.action == 'apply' then
    local stash_ref = string.format('stash@{%d}', opts.index)
    local _, err = git_stash.apply(repo_path, stash_ref)
    if err then
      console.error(err[1] or tostring(err))
      return
    end
    console.info('Stash applied: ' .. stash_ref)
    return
  end

  if opts.action == 'drop' then
    local stash_ref = string.format('stash@{%d}', opts.index)
    local _, err = git_stash.drop(repo_path, stash_ref)
    if err then
      console.error(err[1] or tostring(err))
      return
    end
    console.info('Stash dropped: ' .. stash_ref)
    return
  end

  if opts.action == 'clear' then
    local _, err = git_stash.clear(repo_path)
    if err then
      console.error(err[1] or tostring(err))
      return
    end
    console.info('All stashes cleared')
    return
  end

  -- Default: show stash screen
  local stashes, list_err = git_stash.list(repo_path)
  if list_err then
    console.error(list_err[1] or tostring(list_err))
    return
  end

  if not stashes or #stashes == 0 then
    console.info('No stashes found')
    return
  end

  display_service.show_stash({
    stashes = stashes,
    repo = repo,
  })
end)

return stash_command
