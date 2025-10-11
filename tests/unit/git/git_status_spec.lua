local async = require('plenary.async.tests')
local git_status = require('vgit.git.git_status')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

local eq = assert.are.same
local truthy = assert.truthy

async.describe('git_status:', function()
  local repo

  async.before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = {
        ['file1.txt'] = { 'line 1', 'line 2' },
        ['file2.txt'] = { 'content' },
      },
    })
    assert(not err, 'Failed to create test repo: ' .. tostring(err))
  end)

  async.after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  async.describe('ls()', function()
    async.it('returns empty list for clean working tree', function()
      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 0)
    end)

    async.it('detects modified file (unstaged)', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'file1.txt')
      eq(files[1].value, ' M')
    end)

    async.it('detects modified file (staged)', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, 'file1.txt')

      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'file1.txt')
      eq(files[1].value, 'M ')
    end)

    async.it('detects untracked file', function()
      test_repo.write_file(repo .. '/new.txt', { 'new' })

      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'new.txt')
      eq(files[1].value, '??')
    end)

    async.it('detects deleted file', function()
      test_repo.delete_file(repo, 'file1.txt', false)

      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'file1.txt')
      eq(files[1].value, ' D')
    end)

    async.it('detects multiple changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.write_file(repo .. '/new.txt', { 'new' })
      test_repo.delete_file(repo, 'file2.txt', false)

      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 3)

      -- Verify all statuses
      local statuses = {}
      for _, file in ipairs(files) do
        statuses[file.filename] = file.value
      end

      eq(statuses['file1.txt'], ' M')
      eq(statuses['new.txt'], '??')
      eq(statuses['file2.txt'], ' D')
    end)

    async.it('detects both staged and unstaged changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'staged' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.modify_file(repo, 'file1.txt', { 'unstaged' })

      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].value, 'MM')
    end)

    async.it('returns single file when filename specified', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.modify_file(repo, 'file2.txt', { 'also modified' })

      local file, err = git_status.ls(repo, 'file1.txt')

      assert(not err)
      assert(file)
      eq(file.filename, 'file1.txt')
      eq(file.value, ' M')
    end)

    async.it('handles files in subdirectories', function()
      test_repo.write_file(repo .. '/subdir/nested.txt', { 'nested' })

      local files, err = git_status.ls(repo)

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'subdir/nested.txt')
      eq(files[1].value, '??')
    end)

    async.it('returns error when reponame is missing', function()
      local files, err = git_status.ls(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not files)
    end)
  end)

  async.describe('tree()', function()
    async.it('detects changes between commits', function()
      -- Create first commit
      test_repo.create_commit(repo, {
        files = { ['new1.txt'] = { 'first' } },
        message = 'First commit',
      })
      local first_commit = test_repo.get_head_commit(repo, false)

      -- Create second commit
      test_repo.create_commit(repo, {
        files = { ['new2.txt'] = { 'second' } },
        message = 'Second commit',
      })
      local second_commit = test_repo.get_head_commit(repo, false)

      -- Get tree diff
      local files, err = git_status.tree(repo, {
        commit_hash = second_commit,
        parent_hash = first_commit,
      })

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'new2.txt')
    end)

    async.it('detects multiple file changes in single commit', function()
      local initial = test_repo.get_head_commit(repo, false)

      -- Make multiple changes
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.write_file(repo .. '/new.txt', { 'new' })
      test_repo.stage(repo, '.')
      test_repo.create_commit(repo, {
        add_all = true,
        message = 'Multiple changes',
      })
      local new_commit = test_repo.get_head_commit(repo, false)

      local files, err = git_status.tree(repo, {
        commit_hash = new_commit,
        parent_hash = initial,
      })

      assert(not err)
      eq(#files, 2)

      local filenames = {}
      for _, file in ipairs(files) do
        table.insert(filenames, file.filename)
      end
      table.sort(filenames)

      truthy(vim.tbl_contains(filenames, 'file1.txt'))
      truthy(vim.tbl_contains(filenames, 'new.txt'))
    end)

    async.it('handles initial commit with empty parent', function()
      -- Create new repo with one commit
      local new_repo = test_repo.create_repo({
        initial_commit = true,
        files = { ['initial.txt'] = { 'content' } },
      })

      local commit = test_repo.get_head_commit(new_repo, false)

      local files, err = git_status.tree(new_repo, {
        commit_hash = commit,
        parent_hash = '',
      })

      assert(not err)
      assert(#files > 0)

      test_repo.cleanup(new_repo)
    end)

    async.it('detects file additions', function()
      local initial = test_repo.get_head_commit(repo, false)

      test_repo.write_file(repo .. '/added.txt', { 'added' })
      test_repo.stage(repo, 'added.txt')
      test_repo.create_commit(repo, {
        files = { ['added.txt'] = { 'added' } },
        message = 'Add file',
      })
      local new_commit = test_repo.get_head_commit(repo, false)

      local files, err = git_status.tree(repo, {
        commit_hash = new_commit,
        parent_hash = initial,
      })

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'added.txt')
      eq(files[1].value, 'A ')
    end)

    async.it('detects file modifications', function()
      local initial = test_repo.get_head_commit(repo, false)

      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'modified' } },
        message = 'Modify file',
      })
      local new_commit = test_repo.get_head_commit(repo, false)

      local files, err = git_status.tree(repo, {
        commit_hash = new_commit,
        parent_hash = initial,
      })

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'file1.txt')
      eq(files[1].value, 'M ')
    end)

    async.it('detects file deletions', function()
      local initial = test_repo.get_head_commit(repo, false)

      test_repo.delete_file(repo, 'file1.txt', true)
      test_repo.create_commit(repo, {
        add_all = true,
        message = 'Delete file',
      })
      local new_commit = test_repo.get_head_commit(repo, false)

      local files, err = git_status.tree(repo, {
        commit_hash = new_commit,
        parent_hash = initial,
      })

      assert(not err)
      eq(#files, 1)
      assert(files[1])
      eq(files[1].filename, 'file1.txt')
      eq(files[1].value, 'D ')
    end)

    async.it('returns error when reponame is missing', function()
      local files, err = git_status.tree(nil, {})

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not files)
    end)
  end)
end)
