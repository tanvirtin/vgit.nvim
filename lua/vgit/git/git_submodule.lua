local lazy = require('vgit.core.lazy')

local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_submodule = {}

function git_submodule.add(reponame, url, path, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not url then return nil, { 'url is required' } end
  if not path then return nil, { 'path is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'add')

  if opts.force or opts.f then query:raw_arg('-f') end

  if opts.branch or opts.b then
    query:raw_arg('-b')
    query:raw_arg(opts.branch or opts.b)
  end

  if opts.depth then
    query:raw_arg('--depth')
    query:raw_arg(tostring(opts.depth))
  end

  if opts.name then
    query:raw_arg('--name')
    query:raw_arg(opts.name)
  end

  if opts.reference then
    query:raw_arg('--reference')
    query:raw_arg(opts.reference)
  end

  query:raw_arg(url)
  query:raw_arg(path)

  return query:execute({ config = { 'protocol.file.allow=always' } })
end

function git_submodule.list(reponame, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'status')

  if opts.recursive then query:raw_arg('--recursive') end

  if opts.cached then query:raw_arg('--cached') end

  local result, err = query:execute()
  if err then return nil, err end

  -- Parse output: " commit-hash path (tag/branch)" or "+commit-hash path (tag/branch)"
  local submodules = {}
  for _, line in ipairs(result) do
    local status_char = line:sub(1, 1)
    local rest = line:sub(2)
    local hash, path, ref = rest:match('^(%S+)%s+(%S+)%s*%((.*)%)')

    if not hash then
      hash, path = rest:match('^(%S+)%s+(%S+)')
    end

    if hash and path then
      local status = 'initialized'
      if status_char == '-' then
        status = 'uninitialized'
      elseif status_char == '+' then
        status = 'modified'
      elseif status_char == 'U' then
        status = 'conflicts'
      end

      submodules[#submodules + 1] = {
        hash = hash:match('^%s*(.-)%s*$'),
        path = path:match('^%s*(.-)%s*$'),
        ref = ref and ref:match('^%s*(.-)%s*$') or nil,
        status = status,
      }
    end
  end

  return submodules, nil
end

function git_submodule.init(reponame, paths)
  if not reponame then return nil, { 'reponame is required' } end

  local query = GitQueryBuilder(reponame):raw_args('submodule', 'init')

  if paths then
    if type(paths) == 'string' then
      query:raw_arg(paths)
    elseif type(paths) == 'table' then
      for _, path in ipairs(paths) do
        query:raw_arg(path)
      end
    end
  end

  return query:execute()
end

function git_submodule.deinit(reponame, paths, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'deinit')

  if opts.force or opts.f then query:raw_arg('-f') end

  if opts.all then query:raw_arg('--all') end

  if paths then
    if type(paths) == 'string' then
      query:raw_arg(paths)
    elseif type(paths) == 'table' then
      for _, path in ipairs(paths) do
        query:raw_arg(path)
      end
    end
  end

  return query:execute()
end

function git_submodule.update(reponame, paths, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'update')

  if opts.init then query:raw_arg('--init') end

  if opts.recursive then query:raw_arg('--recursive') end

  if opts.force or opts.f then query:raw_arg('-f') end

  if opts.checkout then query:raw_arg('--checkout') end

  if opts.rebase then query:raw_arg('--rebase') end

  if opts.merge then query:raw_arg('--merge') end

  if opts.remote then query:raw_arg('--remote') end

  if opts.depth then
    query:raw_arg('--depth')
    query:raw_arg(tostring(opts.depth))
  end

  if opts.jobs or opts.j then
    query:raw_arg('-j')
    query:raw_arg(tostring(opts.jobs or opts.j))
  end

  if paths then
    if type(paths) == 'string' then
      query:raw_arg(paths)
    elseif type(paths) == 'table' then
      for _, path in ipairs(paths) do
        query:raw_arg(path)
      end
    end
  end

  return query:execute({ config = { 'protocol.file.allow=always' } })
end

function git_submodule.sync(reponame, paths, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'sync')

  if opts.recursive then query:raw_arg('--recursive') end

  if paths then
    if type(paths) == 'string' then
      query:raw_arg(paths)
    elseif type(paths) == 'table' then
      for _, path in ipairs(paths) do
        query:raw_arg(path)
      end
    end
  end

  return query:execute()
end

function git_submodule.foreach(reponame, command, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not command then return nil, { 'command is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'foreach')

  if opts.recursive then query:raw_arg('--recursive') end

  if opts.quiet or opts.q then query:raw_arg('-q') end

  query:raw_arg(command)

  return query:execute()
end

function git_submodule.set_branch(reponame, branch, path, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not path then return nil, { 'path is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'set-branch')

  if opts.default or opts.d then
    query:raw_arg('-d')
  elseif branch then
    query:raw_arg('-b')
    query:raw_arg(branch)
  else
    return nil, { 'branch is required unless using default option' }
  end

  query:raw_arg(path)

  return query:execute()
end

function git_submodule.set_url(reponame, path, url)
  if not reponame then return nil, { 'reponame is required' } end
  if not path then return nil, { 'path is required' } end
  if not url then return nil, { 'url is required' } end

  return GitQueryBuilder(reponame):raw_args('submodule', 'set-url', path, url):execute()
end

function git_submodule.absorbgitdirs(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('submodule', 'absorbgitdirs'):execute()
end

function git_submodule.summary(reponame, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('submodule', 'summary')

  if opts.cached then query:raw_arg('--cached') end

  if opts.files then query:raw_arg('--files') end

  if opts.summary_limit then
    query:raw_arg('--summary-limit')
    query:raw_arg(tostring(opts.summary_limit))
  end

  if opts.commit then query:raw_arg(opts.commit) end

  return query:execute()
end

return git_submodule
