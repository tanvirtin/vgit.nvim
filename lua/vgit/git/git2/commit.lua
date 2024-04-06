local gitcli = require('vgit.git.git2.gitcli')

local commit = {}

function commit.create(reponame, description)
  if not reponame then return nil, { 'reponame is required' } end

  local lines, err = gitcli.run({ '-C', reponame, 'commit', '-m', description })
  if err then return nil, err end

  local is_uncommitted = false
  local has_no_changes = false

  for i = 1, #lines do
    local line = lines[i]

    if vim.startswith(line, 'no changes added to commit') then
      is_uncommitted = true
    end
    if vim.startswith(line, 'nothing to commit, working tree clean') then
      has_no_changes = true
    end
  end

  if has_no_changes then return nil, { 'Nothing to commit, working tree clean' } end
  if is_uncommitted then return nil, { 'No changes added to commit (use "git add" and/or "git commit -a")' } end

  return true, nil
end

function commit.dry_run(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return gitcli.run({ '-C', reponame, 'commit', '--dry-run' })
end

return commit
