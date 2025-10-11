local utils = require('tests.helpers.utils')

local GitDriver = {}

function GitDriver.create_repo(opts)
  opts = opts or {}

  local GitRepository = require('vgit.git.GitRepository')
  local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

  local temp_dir = vim.fn.tempname()
  local success = utils.mkdir_p(temp_dir)
  if not success then return nil, 'Failed to create directory: ' .. temp_dir end

  temp_dir = utils.resolve_path(temp_dir)

  local _, err = GitQueryBuilder(temp_dir):raw_args('init', '-q'):execute()
  if err then
    utils.rmdir_recursive(temp_dir)
    return nil, 'Failed to init repository'
  end

  GitQueryBuilder(temp_dir):raw_args('config', 'gc.auto', '0'):execute()
  GitQueryBuilder(temp_dir):raw_args('config', 'gc.autodetach', 'false'):execute()
  GitQueryBuilder(temp_dir):raw_args('config', 'user.name', opts.author_name or 'Test User'):execute()
  GitQueryBuilder(temp_dir):raw_args('config', 'user.email', opts.author_email or 'test@example.com'):execute()

  local repo, open_err = GitRepository.open(temp_dir)
  if open_err then
    utils.rmdir_recursive(temp_dir)
    return nil, 'Failed to open repository'
  end

  if opts.files then
    for filename, content in pairs(opts.files) do
      local filepath = temp_dir .. '/' .. filename
      local _, write_err = utils.write_file_internal(filepath, content)
      if write_err then
        utils.rmdir_recursive(temp_dir)
        return nil, write_err
      end
    end

    if opts.initial_commit and repo then
      local index = repo:index()
      if not index then
        utils.rmdir_recursive(temp_dir)
        return nil, 'Failed to get repository index'
      end
      index:add_all()
      local _, commit_err = index:commit(opts.initial_message or 'Initial commit')
      if commit_err then
        utils.rmdir_recursive(temp_dir)
        return nil, 'Failed to create initial commit'
      end
    end
  end

  return repo, nil
end

function GitDriver.write_file(repo, filename, content)
  local filepath = repo:get_path() .. '/' .. filename
  return utils.write_file_internal(filepath, content)
end

function GitDriver.create_commit(repo, opts)
  opts = opts or {}

  if opts.files then
    for filename, content in pairs(opts.files) do
      local _, err = GitDriver.write_file(repo, filename, content)
      if err then return nil, err end
    end
  end

  local index = repo:index()

  if opts.add_all then
    index:add_all()
  elseif opts.files then
    for filename, _ in pairs(opts.files) do
      local _, err = index:add(filename)
      if err then return nil, err end
    end
  end

  local _, err = index:commit(opts.message or 'Test commit')
  if err then return nil, err end

  return true, nil
end

function GitDriver.create_branch(repo, name, opts)
  opts = opts or {}

  local refs = repo:refs()
  local _, err = refs:create_branch(name)
  if err then return nil, err end

  if opts.checkout ~= false then
    local _, checkout_err = refs:checkout(name)
    if checkout_err then return nil, checkout_err end
  end

  return true, nil
end

function GitDriver.checkout(repo, ref)
  local refs = repo:refs()
  return refs:checkout(ref)
end

function GitDriver.create_conflict(repo, opts)
  opts = opts or {}
  local filename = opts.filename or 'conflict.txt'

  local _, err = GitDriver.create_commit(repo, {
    files = { [filename] = { 'line 1', 'base line 2', 'line 3' } },
    message = 'Base commit',
  })
  if err then return nil, err end

  local _, branch_err = GitDriver.create_branch(repo, 'feature')
  if branch_err then return nil, branch_err end

  _, err = GitDriver.create_commit(repo, {
    files = { [filename] = { 'line 1', 'feature line 2', 'line 3' } },
    message = 'Feature commit',
  })
  if err then return nil, err end

  _, err = GitDriver.checkout(repo, 'master')
  if err then
    _, err = GitDriver.checkout(repo, 'main')
    if err then return nil, 'Could not checkout main branch' end
  end

  _, err = GitDriver.create_commit(repo, {
    files = { [filename] = { 'line 1', 'main line 2', 'line 3' } },
    message = 'Main commit',
  })
  if err then return nil, err end

  local _, _ = repo:merge('feature', { no_edit = true })

  return true, nil
end

function GitDriver.get_head_commit(repo, short)
  local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

  local args = { 'rev-parse' }
  if short then table.insert(args, '--short') end
  table.insert(args, 'HEAD')

  local result, _ = GitQueryBuilder(repo:get_path()):raw_args(table.unpack(args)):execute()

  if result and result[1] then return result[1]:match('^%s*(.-)%s*$') end

  return nil
end

function GitDriver.get_path(repo)
  return repo:get_path()
end

function GitDriver.cleanup(repo)
  local path = repo:get_path()
  if not path or path == '' or path == '/' then return false end
  return utils.rmdir_recursive(path)
end

return GitDriver
