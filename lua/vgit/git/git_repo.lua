local gitcli = require('vgit.git.gitcli')

local git_repo = {}

function git_repo.config(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return gitcli.run({ '-C', reponame, 'config', '--list' })
end

function git_repo.discover(filepath)
  local dirname = (filepath and vim.fn.fnamemodify(filepath, ':p:h')) or vim.loop.cwd()
  local result, err = gitcli.run({ '-C', dirname, 'rev-parse', '--show-toplevel' })

  if err then return nil, err end
  if #result == 0 then return nil, {} end
  return result[1]
end

function git_repo.dirname()
  local reponame, err = git_repo.discover()
  if err then return nil, err end

  local result, git_dir_err = gitcli.run({ '-C', reponame, 'rev-parse', '--git-dir' })
  local git_dir = result[1]
  if git_dir_err then return nil, git_dir_err end
  if #result == 0 then return nil, {} end

  return reponame .. '/' .. git_dir
end

function git_repo.exists(filepath)
  local dirname = (filepath and vim.fn.fnamemodify(filepath, ':p:h')) or vim.loop.cwd()
  local _, err = gitcli.run({ '-C', dirname, 'rev-parse', '--is-inside-git-dir' })

  if err then return false end
  return true
end

function git_repo.has(reponame, filename, commit)
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
  if #result == 0 then return false end
  return true
end

function git_repo.ignores(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local result, err = gitcli.run({ '-C', reponame, '--no-pager', 'check-ignore', filename })

  if err then return nil, err end
  if #result == 0 then return false end
  return true
end

function git_repo.checkout(reponame, name)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'name is required' } end
  return gitcli.run({ '-C', reponame, '--no-pager', 'checkout', '--quiet', name })
end

function git_repo.reset(reponame, filename)
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

function git_repo.clean(reponame, filename)
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

return git_repo
