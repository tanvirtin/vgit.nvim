local Path = require('plenary.path')
local gitcli = require('vgit.git.gitcli')

local function git_command(path, ...)
  return gitcli.run({ '-C', path, ... })
end

local git_toolkit = {}

function git_toolkit.setup_repo(path)
  vim.fn.mkdir(path, "p")
  git_command(path, 'init')

  return path
end

function git_toolkit.cleanup_repo(path)
  vim.fn.delete(path, 'rf')
end

function git_toolkit.create_file(path, filename, content)
  local file_path = Path:new(path, filename)
  file_path:write(content, 'w')
end

function git_toolkit.modify_file(path, filename, content)
  local file_path = Path:new(path, filename)
  file_path:write(content, 'a')
end

function git_toolkit.delete_file(path, filename)
  local file_path = Path:new(path, filename)
  file_path:rm()
end

function git_toolkit.stage_file(path, filename)
  return git_command(path, 'add', filename)
end

function git_toolkit.commit_file(path, message)
  return git_command(path, 'commit', '-m', message)
end

function git_toolkit.create_branch(path, branch_name)
  return git_command(path, 'checkout', '-b', branch_name)
end

function git_toolkit.switch_branch(path, branch_name)
  return git_command(path, 'checkout', branch_name)
end

function git_toolkit.create_untracked_file(repo_path, filename)
  git_toolkit.create_file(repo_path, filename, 'Untracked content')
end

function git_toolkit.create_modified_file(repo_path, filename)
  git_toolkit.create_file(repo_path, filename, 'Initial content')
  git_toolkit.stage_file(repo_path, filename)
  git_toolkit.commit_file(repo_path, 'Initial commit')
  git_toolkit.modify_file(repo_path, filename, '\nModified content')
end

function git_toolkit.create_staged_modified_file(repo_path, filename)
  git_toolkit.create_modified_file(repo_path, filename)
  git_toolkit.stage_file(repo_path, filename)
end

function git_toolkit.create_modified_staged_modified_file(repo_path, filename)
  git_toolkit.create_staged_modified_file(repo_path, filename)
  git_toolkit.modify_file(repo_path, filename, '\nAdditional modification')
end

function git_toolkit.create_new_staged_file(repo_path, filename)
  git_toolkit.create_file(repo_path, filename, 'New file content')
  git_toolkit.stage_file(repo_path, filename)
end

function git_toolkit.create_deleted_file(repo_path, filename)
  git_toolkit.create_file(repo_path, filename, 'Content')
  git_toolkit.stage_file(repo_path, filename)
  git_toolkit.commit_file(repo_path, 'Add file')
  git_toolkit.delete_file(repo_path, filename)
end

function git_toolkit.create_staged_deleted_file(repo_path, filename)
  git_toolkit.create_deleted_file(repo_path, filename)
  git_toolkit.stage_file(repo_path, filename)
end

function git_toolkit.create_renamed_file(reponame, old_filename, new_filename)
  git_toolkit.create_file(reponame, old_filename, 'Content')
  git_toolkit.stage_file(reponame, old_filename)
  git_toolkit.commit_file(reponame, 'Add file')
  git_command(reponame, 'mv', old_filename, new_filename)
  git_toolkit.stage_file(reponame, new_filename)
end

function git_toolkit.create_ignored_file(repo_path, filename)
  git_toolkit.create_file(repo_path, '.gitignore', filename)
  git_toolkit.create_file(repo_path, filename, 'Ignored content')
end

function git_toolkit.create_unmerged_file(repo_path, filename)
  git_toolkit.create_file(repo_path, filename, 'Initial content')
  git_toolkit.stage_file(repo_path, filename)
  git_toolkit.commit_file(repo_path, 'Initial commit')

  git_toolkit.create_branch(repo_path, 'branch1')
  git_toolkit.modify_file(repo_path, filename, '\nBranch 1 modification')
  git_toolkit.stage_file(repo_path, filename)
  git_toolkit.commit_file(repo_path, 'Branch 1 commit')

  git_command(repo_path, 'checkout', 'main')
  git_toolkit.modify_file(repo_path, filename, '\nMain branch modification')
  git_toolkit.stage_file(repo_path, filename)
  git_toolkit.commit_file(repo_path, 'Main branch commit')

  git_command(repo_path, 'merge', 'branch1')
end

function git_toolkit.create_unmerged_file_ud(reponame, filename)
  git_toolkit.create_file(reponame, filename, 'Initial content')
  git_toolkit.stage_file(reponame, filename)
  git_toolkit.commit_file(reponame, 'Initial commit')

  git_toolkit.create_branch(reponame, 'branch1')
  git_toolkit.delete_file(reponame, filename)
  git_toolkit.stage_file(reponame, filename)
  git_toolkit.commit_file(reponame, 'Delete file in branch1')

  git_toolkit.switch_branch(reponame, 'main')
  git_toolkit.modify_file(reponame, filename, 'Modified in main')
  git_toolkit.stage_file(reponame, filename)
  git_toolkit.commit_file(reponame, 'Modify file in main')

  git_command(reponame, 'merge', 'branch1')
end

function git_toolkit.create_unmerged_file_du(reponame, filename)
  git_toolkit.create_file(reponame, filename, 'Initial content')
  git_toolkit.stage_file(reponame, filename)
  git_toolkit.commit_file(reponame, 'Initial commit')

  git_toolkit.create_branch(reponame, 'branch1')
  git_toolkit.modify_file(reponame, filename, 'Modified in branch1')
  git_toolkit.stage_file(reponame, filename)
  git_toolkit.commit_file(reponame, 'Modify file in branch1')

  git_toolkit.switch_branch(reponame, 'main')
  git_toolkit.delete_file(reponame, filename)
  git_toolkit.stage_file(reponame, filename)
  git_toolkit.commit_file(reponame, 'Delete file in main')

  git_command(reponame, 'merge', 'branch1')
end

return git_toolkit
