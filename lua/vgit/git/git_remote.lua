local lazy = require('vgit.core.lazy')

local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_remote = {}

-- List all remotes with their URLs
function git_remote.list(reponame, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('remote')

  if opts.verbose then query:raw_arg('-v') end

  local result, err = query:execute()
  if err then return nil, err end

  if opts.verbose then
    -- Parse verbose output: "origin  https://github.com/user/repo.git (fetch)"
    local remotes = {}
    local seen = {}

    for _, line in ipairs(result) do
      local name, url, type = line:match('^(%S+)%s+(%S+)%s+%((%w+)%)$')
      if name and url then
        if not seen[name] then
          remotes[#remotes + 1] = {
            name = name,
            fetch_url = nil,
            push_url = nil,
          }
          seen[name] = #remotes
        end

        local idx = seen[name]
        if type == 'fetch' then
          remotes[idx].fetch_url = url
        elseif type == 'push' then
          remotes[idx].push_url = url
        end
      end
    end

    return remotes, nil
  else
    -- Simple list of remote names
    local remotes = {}
    for _, name in ipairs(result) do
      if name ~= '' then remotes[#remotes + 1] = { name = name } end
    end
    return remotes, nil
  end
end

-- Get URL for a specific remote
function git_remote.get_url(reponame, remote, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not remote then return nil, { 'remote name is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('remote', 'get-url')

  if opts.push then query:raw_arg('--push') end

  query:raw_arg(remote)

  local result, err = query:execute()
  if err then return nil, err end

  return result[1], nil
end

-- Add a new remote
function git_remote.add(reponame, name, url, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'remote name is required' } end
  if not url then return nil, { 'url is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('remote', 'add')

  if opts.fetch then query:raw_arg('-f') end

  if opts.tags ~= nil then
    if opts.tags then
      query:raw_arg('--tags')
    else
      query:raw_arg('--no-tags')
    end
  end

  if opts.track then
    query:raw_arg('-t')
    query:raw_arg(opts.track)
  end

  if opts.mirror then query:raw_arg('--mirror=' .. opts.mirror) end

  query:raw_arg(name)
  query:raw_arg(url)

  return query:execute()
end

-- Remove a remote
function git_remote.remove(reponame, name)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'remote name is required' } end

  return GitQueryBuilder(reponame):raw_args('remote', 'remove', name):execute()
end

-- Rename a remote
function git_remote.rename(reponame, old_name, new_name)
  if not reponame then return nil, { 'reponame is required' } end
  if not old_name then return nil, { 'old name is required' } end
  if not new_name then return nil, { 'new name is required' } end

  return GitQueryBuilder(reponame):raw_args('remote', 'rename', old_name, new_name):execute()
end

-- Set URL for a remote
function git_remote.set_url(reponame, name, url, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'remote name is required' } end
  if not url then return nil, { 'url is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('remote', 'set-url')

  if opts.push then query:raw_arg('--push') end

  if opts.add then query:raw_arg('--add') end

  if opts.delete then query:raw_arg('--delete') end

  query:raw_arg(name)
  query:raw_arg(url)

  return query:execute()
end

-- Show information about a remote
function git_remote.show(reponame, name)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'remote name is required' } end

  local result, err = GitQueryBuilder(reponame):raw_args('remote', 'show', name):execute()
  if err then return nil, err end

  -- Parse the output
  local info = {
    name = name,
    fetch_url = nil,
    push_url = nil,
    head_branch = nil,
    remote_branches = {},
    local_branches = {},
    stale = {},
  }

  local section = nil
  for _, line in ipairs(result) do
    if line:match('^%s*Fetch URL:') then
      info.fetch_url = line:match(':%s*(.+)$')
    elseif line:match('^%s*Push%s+URL:') then
      info.push_url = line:match(':%s*(.+)$')
    elseif line:match('^%s*HEAD branch:') then
      info.head_branch = line:match(':%s*(.+)$')
    elseif line:match('^%s*Remote branch') then
      section = 'remote_branches'
    elseif line:match('^%s*Local branch') then
      section = 'local_branches'
    elseif line:match('^%s*Local ref') then
      section = 'local_refs'
    elseif section and line:match('^%s+%S') then
      local branch = line:match('^%s*(.-)%s*$') -- trim whitespace
      if section == 'remote_branches' then
        table.insert(info.remote_branches, branch)
      elseif section == 'local_branches' then
        table.insert(info.local_branches, branch)
      end
    end
  end

  return info, nil
end

-- Prune stale remote-tracking branches
function git_remote.prune(reponame, name, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'remote name is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('remote', 'prune')

  if opts.dry_run then query:raw_arg('--dry-run') end

  query:raw_arg(name)

  return query:execute()
end

-- Update remote-tracking branches
function git_remote.update(reponame, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('remote', 'update')

  if opts.prune then query:raw_arg('--prune') end

  if opts.remote then query:raw_arg(opts.remote) end

  return query:execute()
end

-- Fetch from a remote
function git_remote.fetch(reponame, remote, refspec, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('fetch')

  if opts.all then query:raw_arg('--all') end

  if opts.prune then query:raw_arg('--prune') end

  if opts.tags then query:raw_arg('--tags') end

  if opts.depth then query:raw_arg('--depth=' .. opts.depth) end

  if opts.dry_run then query:raw_arg('--dry-run') end

  if opts.force then query:raw_arg('--force') end

  if remote then query:raw_arg(remote) end

  if refspec then query:raw_arg(refspec) end

  return query:execute()
end

-- Push to a remote
function git_remote.push(reponame, remote, refspec, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('push')

  if opts.all then query:raw_arg('--all') end

  if opts.tags then query:raw_arg('--tags') end

  if opts.force then query:raw_arg('--force') end

  if opts.force_with_lease then
    if type(opts.force_with_lease) == 'string' then
      query:raw_arg('--force-with-lease=' .. opts.force_with_lease)
    else
      query:raw_arg('--force-with-lease')
    end
  end

  if opts.delete then query:raw_arg('--delete') end

  if opts.dry_run then query:raw_arg('--dry-run') end

  if opts.set_upstream then query:raw_arg('--set-upstream') end

  if opts.upstream or opts.u then query:raw_arg('-u') end

  if remote then query:raw_arg(remote) end

  if refspec then query:raw_arg(refspec) end

  return query:execute()
end

-- Pull from a remote
function git_remote.pull(reponame, remote, refspec, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('pull')

  if opts.rebase then query:raw_arg('--rebase') end

  if opts.no_rebase then query:raw_arg('--no-rebase') end

  if opts.ff_only then query:raw_arg('--ff-only') end

  if opts.no_ff then query:raw_arg('--no-ff') end

  if opts.squash then query:raw_arg('--squash') end

  if opts.tags then query:raw_arg('--tags') end

  if opts.depth then query:raw_arg('--depth=' .. opts.depth) end

  if opts.force then query:raw_arg('--force') end

  if remote then query:raw_arg(remote) end

  if refspec then query:raw_arg(refspec) end

  return query:execute()
end

return git_remote
