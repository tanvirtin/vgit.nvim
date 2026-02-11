local utils = require('tests.helpers.utils')
local RawDriver = require('tests.helpers.raw_driver')
local GitDriver = require('tests.helpers.git_driver')

local M = {}

M.drivers = {
  raw = RawDriver,
  git = GitDriver,
}

M.active_driver = RawDriver

function M.use_driver(driver_name)
  local driver = M.drivers[driver_name]
  if not driver then error('Unknown driver: ' .. driver_name) end
  M.active_driver = driver
end

function M.create_repo(opts)
  return M.active_driver.create_repo(opts)
end

function M.write_file(repo, filename, content)
  if content == nil and type(filename) == 'table' then
    local filepath = repo
    content = filename
    return utils.write_file_internal(filepath, content)
  end
  return M.active_driver.write_file(repo, filename, content)
end

function M.create_commit(repo, opts)
  return M.active_driver.create_commit(repo, opts)
end

function M.create_branch(repo, name, opts)
  return M.active_driver.create_branch(repo, name, opts)
end

function M.checkout(repo, ref)
  return M.active_driver.checkout(repo, ref)
end

function M.create_conflict(repo, opts)
  return M.active_driver.create_conflict(repo, opts)
end

function M.get_head_commit(repo, short)
  return M.active_driver.get_head_commit(repo, short)
end

function M.get_path(repo)
  return M.active_driver.get_path(repo)
end

function M.modify_file(repo, filename, new_content)
  return M.write_file(repo, filename, new_content)
end

function M.delete_file(repo, filename, staged)
  if type(repo) == 'string' and repo:match('/') and (filename == true or filename == false or filename == nil) then
    local filepath = repo
    staged = filename
    local success, err = vim.loop.fs_unlink(filepath)
    if not success then return false, 'Failed to delete file: ' .. filepath .. ' (' .. tostring(err) .. ')' end
    if staged then
      local repo_path = filepath:match('(.+)/[^/]+$')
      local file_name = filepath:match('.+/([^/]+)$')
      local _, git_err = utils.git_exec({ 'git', '-C', repo_path, 'rm', file_name }, { check = true })
      if git_err then return false, 'Failed to stage deletion' end
    end
    return true, nil
  end

  local path = M.get_path(repo)
  local filepath = path .. '/' .. filename
  local success, err = vim.loop.fs_unlink(filepath)

  if not success then return false, 'Failed to delete file: ' .. filepath .. ' (' .. tostring(err) .. ')' end

  if staged and M.active_driver == RawDriver then
    local _, git_err = utils.git_exec({ 'git', '-C', path, 'rm', filename }, { check = true })
    if git_err then return false, 'Failed to stage deletion' end
  end

  return true, nil
end

function M.stage(repo, files)
  if M.active_driver == RawDriver then
    local path = M.get_path(repo)
    files = files or '.'
    local file_list = type(files) == 'table' and files or { files }

    for _, file in ipairs(file_list) do
      local _, err = utils.git_exec({ 'git', '-C', path, 'add', file }, { check = true })
      if err then return false, 'Failed to stage file: ' .. file .. ' - ' .. err end
    end

    return true, nil
  else
    local index = repo:index()
    if type(files) == 'table' then
      for _, file in ipairs(files) do
        local _, err = index:add(file)
        if err then return false, err end
      end
    else
      local _, err = index:add(files or '.')
      if err then return false, err end
    end
    return true, nil
  end
end

function M.create_tag(repo, name, opts)
  return M.active_driver.create_tag(repo, name, opts)
end

function M.detach_head(repo, commit)
  return M.active_driver.detach_head(repo, commit)
end

function M.create_merge_commit(repo, opts)
  return M.active_driver.create_merge_commit(repo, opts)
end

function M.add_submodule(repo, source_path, submodule_path)
  return M.active_driver.add_submodule(repo, source_path, submodule_path)
end

function M.init_submodules(repo)
  return M.active_driver.init_submodules(repo)
end

function M.update_submodules(repo, opts)
  return M.active_driver.update_submodules(repo, opts)
end

function M.cleanup(repo)
  return M.active_driver.cleanup(repo)
end

function M.preserve(repo)
  local path = M.get_path(repo)
  print('[DEBUG] Test repository preserved at: ' .. path)
  print('[DEBUG] To inspect: cd ' .. path .. ' && git status')
end

return M
