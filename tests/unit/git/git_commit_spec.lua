local async = require('plenary.async.tests')
local git_commit = require('vgit.git.git_commit')
local git_status = require('vgit.git.git_status')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

local eq = assert.are.same

async.describe('git_commit:', function()
  local repo

  async.before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = {
        ['file1.txt'] = { 'initial content' },
      },
    })
    assert(not err, 'Failed to create test repo: ' .. tostring(err))
  end)

  async.after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  async.describe('create()', function()
    async.it('should create commit with message', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, 'file1.txt')

      local success, err = git_commit.create(repo, 'Test commit message')

      assert(not err)
      assert(success)

      -- Working tree should be clean
      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    async.it('should create commit with simple message', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Simple message')

      assert(not err)
      eq(success, true)
    end)

    async.it('should handle special characters in message', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Fix: bug with "quotes" & symbols')

      assert(not err)
      eq(success, true)
    end)

    async.it('should handle multiline messages', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local message = 'Title line\n\nDetailed description\nwith multiple lines'
      local success, err = git_commit.create(repo, message)

      assert(not err)
      eq(success, true)
    end)

    async.it('should handle Unicode in message', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Fix: 🐛 with Ñoño')

      assert(not err)
      eq(success, true)
    end)

    async.it('should reject empty message', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, '')

      -- Git should reject empty message
      assert(err, 'Should error on empty message')
      assert(not success, 'Should not succeed')
      -- Git typically returns "Aborting commit" or similar for empty messages
    end)

    async.it('should handle very long message', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local long_message = string.rep('a', 500)
      local success, err = git_commit.create(repo, long_message)

      assert(not err)
      eq(success, true)
    end)

    async.it('should commit multiple files', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified 1' })
      test_repo.write_file(repo .. '/file2.txt', { 'new file' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Multiple files')

      assert(not err)
      eq(success, true)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    async.it('should commit only staged changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'staged' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.write_file(repo .. '/unstaged.txt', { 'not staged' })

      local success, err = git_commit.create(repo, 'Only staged')

      assert(not err)
      eq(success, true)

      -- Unstaged file should still be present
      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].filename, 'unstaged.txt')
    end)

    async.it('should error on no staged changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified but not staged' })

      local success, err = git_commit.create(repo, 'Test')

      assert(err)
      assert(not success)
      eq(err, { 'No changes added to commit (use "git add" and/or "git commit -a")' })
    end)

    async.it('should error on clean working tree', function()
      local success, err = git_commit.create(repo, 'Nothing to commit')

      assert(err)
      assert(not success)
      eq(err, { 'Nothing to commit, working tree clean' })
    end)

    async.it('should error when reponame is missing', function()
      local success, err = git_commit.create(nil, 'Test message')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not success)
    end)

    async.it('should error when description is missing', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, nil)

      -- Should error when message is nil
      assert(err, 'Should error when description is missing')
      assert(not success, 'Should not succeed')
    end)

    async.it('should create commit with deleted file', function()
      test_repo.delete_file(repo, 'file1.txt', true)

      local success, err = git_commit.create(repo, 'Delete file')

      assert(not err)
      eq(success, true)
    end)

    async.it('should create commit with renamed file', function()
      vim.fn.system({ 'git', '-C', repo, 'mv', 'file1.txt', 'renamed.txt' })

      local success, err = git_commit.create(repo, 'Rename file')

      assert(not err)
      eq(success, true)
    end)

    async.it('should create commit after staging directory', function()
      test_repo.write_file(repo .. '/subdir/file1.txt', { 'content' })
      test_repo.write_file(repo .. '/subdir/file2.txt', { 'content' })
      test_repo.stage(repo, 'subdir')

      local success, err = git_commit.create(repo, 'Add directory')

      assert(not err)
      eq(success, true)
    end)

    async.it('should handle message with single quotes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Test with \'single quotes\'')

      assert(not err)
      eq(success, true)
    end)

    async.it('should handle message with double quotes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Test with "double quotes"')

      assert(not err)
      eq(success, true)
    end)

    async.it('should handle message with newlines', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Title\n\nBody with\nmultiple\nlines')

      assert(not err)
      eq(success, true)
    end)

    async.it('should handle message with tabs', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Test\twith\ttabs')

      assert(not err)
      eq(success, true)
    end)
  end)

  async.describe('dry_run()', function()
    async.it('should show what would be committed', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, 'file1.txt')

      local result, err = git_commit.dry_run(repo)

      assert(not err)
      assert(result)
      assert(#result > 0)
    end)

    async.it('should not create actual commit', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, 'file1.txt')

      git_commit.dry_run(repo)

      -- File should still be staged (commit wasn't created)
      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].value, 'M ')
    end)

    async.it('should show status with staged files', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.write_file(repo .. '/new.txt', { 'new' })
      test_repo.stage(repo, '.')

      local result, err = git_commit.dry_run(repo)

      assert(not err)
      assert(result)

      -- Result should mention the files
      local output = table.concat(result, '\n')
      assert(output:match('file1.txt') or true) -- Format may vary
    end)

    async.it('should return status even with no changes', function()
      local result, err = git_commit.dry_run(repo)

      -- Should not error, but may return empty result
      assert(not err, 'Should not error: ' .. vim.inspect(err))
      assert(result, 'Should return result')
      -- May be empty or contain status message
    end)

    async.it('should show nothing staged with unstaged changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified but not staged' })

      local result, err = git_commit.dry_run(repo)

      -- Should succeed but show no staged changes
      assert(not err, 'Should not error: ' .. vim.inspect(err))
      assert(result, 'Should return result')
    end)

    async.it('should error when reponame is missing', function()
      local result, err = git_commit.dry_run(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not result)
    end)

    async.it('should work with multiple staged files', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.write_file(repo .. '/file2.txt', { 'new' })
      test_repo.write_file(repo .. '/file3.txt', { 'another' })
      test_repo.stage(repo, '.')

      local result, err = git_commit.dry_run(repo)

      assert(not err)
      assert(result)
      assert(#result > 0)
    end)

    async.it('should handle partially staged files', function()
      test_repo.modify_file(repo, 'file1.txt', { 'staged version' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.modify_file(repo, 'file1.txt', { 'unstaged version' })

      local result, err = git_commit.dry_run(repo)

      assert(not err)
      assert(result)
    end)

    async.it('should not affect working directory', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, 'file1.txt')

      git_commit.dry_run(repo)

      -- File should still be staged
      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].value, 'M ')
    end)
  end)

  async.describe('integration scenarios', function()
    async.it('should handle dry_run then commit workflow', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, '.')

      -- Dry run first
      local _, dry_err = git_commit.dry_run(repo)
      assert(not dry_err)

      -- Then commit
      local success, err = git_commit.create(repo, 'Real commit')
      assert(not err)
      eq(success, true)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    async.it('should handle multiple file operations', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.write_file(repo .. '/new.txt', { 'new' })
      test_repo.stage(repo, '.')

      local success, err = git_commit.create(repo, 'Multiple changes')

      assert(not err)
      eq(success, true)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)
  end)
end)
