local gitcli = require('vgit.git.git2.gitcli')

local repo = {}

function repo.config()
  return gitcli.run({ '-C', vim.loop.cwd(), 'config', '--list' })
end

function repo.discover(filepath)
  local dirname = (filepath and vim.fn.fnamemodify(filepath, ':p:h')) or vim.loop.cwd()
  local result, err = gitcli.run({ '-C', dirname, 'rev-parse', '--show-toplevel' })

  if err then return nil, err end
  return result[1], nil
end

function repo.exists(filepath)
  local dirname = (filepath and vim.fn.fnamemodify(filepath, ':p:h')) or vim.loop.cwd()
  local _, err = gitcli.run({ '-C', dirname, 'rev-parse', '--is-inside-git-dir' })

  if err then return false, nil end
  return true, nil
end

function repo.has(reponame, filename, commit)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  commit = commit or 'HEAD'

  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'ls-files',
    '--exclude-standard',
    commit,
    filename,
  })

  if err then return nil, err end
  if #result == 0 then return false, nil end
  return true, nil
end

function repo.ignores(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local result, err = gitcli.run({ '-C', reponame, '--no-pager', 'check-ignore', filename })

  if err then return nil, err end
  if #result == 0 then return false, nil end
  return true, nil
end

function repo.checkout(reponame, name)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'name is required' } end
  return gitcli.run({ '-C', reponame, '--no-pager', 'checkout', '--quiet', name })
end

function repo.reset(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local _, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'checkout',
    '-q',
    '--',
    filename or '.',
  })
  if err then return nil, err end

  return gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'clean',
    '-fd',
    '--',
    filename or '.',
  })
end

function repo.clean(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  return gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'clean',
    '-fd',
    '--',
    filename or '.',
  })
end

return repo
