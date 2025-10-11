local utils = require('tests.helpers.utils')

local RawDriver = {}

function RawDriver.create_repo(opts)
  opts = opts or {}

  local temp_dir = vim.fn.tempname()
  local mkdir_success = utils.mkdir_p(temp_dir)
  if not mkdir_success then return nil, 'Failed to create temporary directory: ' .. temp_dir end

  temp_dir = utils.resolve_path(temp_dir)

  local _, init_err = utils.git_exec({ 'git', '-C', temp_dir, 'init', '-q' }, { check = true })
  if init_err then
    utils.rmdir_recursive(temp_dir)
    return nil, init_err
  end

  utils.git_exec({ 'git', '-C', temp_dir, 'config', 'gc.auto', '0' })
  utils.git_exec({ 'git', '-C', temp_dir, 'config', 'gc.autodetach', 'false' })
  utils.git_exec({ 'git', '-C', temp_dir, 'config', 'user.name', opts.author_name or 'Test User' })
  utils.git_exec({ 'git', '-C', temp_dir, 'config', 'user.email', opts.author_email or 'test@example.com' })

  if opts.branch then utils.git_exec({ 'git', '-C', temp_dir, 'checkout', '-q', '-b', opts.branch }) end

  if opts.files then
    for filename, content in pairs(opts.files) do
      local filepath = temp_dir .. '/' .. filename
      local _, write_err = utils.write_file_internal(filepath, content)
      if write_err then
        utils.rmdir_recursive(temp_dir)
        return nil, write_err
      end
    end
  end

  if opts.initial_commit and opts.files then
    local _, add_err = utils.git_exec({ 'git', '-C', temp_dir, 'add', '.' }, { check = true })
    if add_err then
      utils.rmdir_recursive(temp_dir)
      return nil, 'Failed to add files: ' .. add_err
    end

    local _, commit_err = utils.git_exec({
      'git',
      '-C',
      temp_dir,
      'commit',
      '-q',
      '-m',
      opts.initial_message or 'Initial commit',
    }, { check = true })
    if commit_err then
      utils.rmdir_recursive(temp_dir)
      return nil, 'Failed to commit: ' .. commit_err
    end
  end

  return temp_dir, nil
end

function RawDriver.write_file(repo, filename, content)
  local filepath = repo .. '/' .. filename
  return utils.write_file_internal(filepath, content)
end

function RawDriver.create_commit(repo, opts)
  opts = opts or {}

  if opts.files then
    for filename, content in pairs(opts.files) do
      local _, err = RawDriver.write_file(repo, filename, content)
      if err then return nil, err end
    end
  end

  if opts.files and not opts.add_all then
    for filename, _ in pairs(opts.files) do
      local _, err = utils.git_exec({ 'git', '-C', repo, 'add', filename }, { check = true })
      if err then return nil, 'Failed to stage file: ' .. filename end
    end
  else
    local _, err = utils.git_exec({ 'git', '-C', repo, 'add', '.' }, { check = true })
    if err then return nil, 'Failed to stage files' end
  end

  local commit_args = { 'git', '-C', repo, 'commit', '-q', '-m', opts.message or 'Test commit' }
  if opts.author then table.insert(commit_args, '--author=' .. opts.author) end
  if opts.date then table.insert(commit_args, '--date=' .. opts.date) end

  local _, err = utils.git_exec(commit_args, { check = true })
  if err then return nil, 'Failed to create commit: ' .. err end

  return true, nil
end

function RawDriver.create_branch(repo, name, opts)
  opts = opts or {}

  local args = { 'git', '-C', repo }

  if opts.checkout ~= false then
    table.insert(args, 'checkout')
    table.insert(args, '-q')
    table.insert(args, '-b')
  else
    table.insert(args, 'branch')
  end

  table.insert(args, name)

  if opts.from then table.insert(args, opts.from) end

  local _, err = utils.git_exec(args, { check = true })
  if err then return nil, 'Failed to create branch: ' .. err end

  return true, nil
end

function RawDriver.checkout(repo, ref)
  local _, err = utils.git_exec({ 'git', '-C', repo, 'checkout', '-q', ref }, { check = true })
  if err then return nil, 'Failed to checkout: ' .. err end
  return true, nil
end

function RawDriver.create_conflict(repo, opts)
  opts = opts or {}
  local filename = opts.filename or 'conflict.txt'
  local base_content = opts.base_content or { 'line 1', 'base line 2', 'line 3' }
  local branch_content = opts.branch_content or { 'line 1', 'branch line 2', 'line 3' }

  local _, err = RawDriver.create_commit(repo, {
    files = { [filename] = base_content },
    message = 'Base commit',
  })
  if err then return nil, err end

  local success
  success, err = RawDriver.create_branch(repo, 'conflict-branch')
  if not success then return nil, err end

  success, err = RawDriver.create_commit(repo, {
    files = { [filename] = branch_content },
    message = 'Branch commit',
  })
  if not success then return nil, err end

  success, _ = RawDriver.checkout(repo, 'master')
  if not success then
    success, err = RawDriver.checkout(repo, 'main')
    if not success then return nil, err end
  end

  local main_content = opts.main_content or { 'line 1', 'main line 2', 'line 3' }
  success, err = RawDriver.create_commit(repo, {
    files = { [filename] = main_content },
    message = 'Main commit',
  })
  if not success then return nil, err end

  utils.git_exec({ 'git', '-C', repo, 'merge', 'conflict-branch', '--no-edit' })

  return true, nil
end

function RawDriver.get_head_commit(repo, short)
  local args = { 'git', '-C', repo, 'rev-parse' }
  if short then table.insert(args, '--short') end
  table.insert(args, 'HEAD')

  local result, _ = utils.git_exec(args)
  if not result then return nil end

  return vim.trim(result)
end

function RawDriver.get_path(repo)
  return repo
end

function RawDriver.cleanup(repo)
  if not repo or repo == '' or repo == '/' then return false end
  return utils.rmdir_recursive(repo)
end

return RawDriver
