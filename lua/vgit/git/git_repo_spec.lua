local git_repo = require('vgit.git.git_repo')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('git_repo:', function()
  local repo

  before_each(function()
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

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('discover()', function()
    it('should discover repo from directory', function()
      local reponame, err = git_repo.discover(repo)

      assert(not err)
      assert(reponame)
      eq(reponame, repo)
    end)

    it('should discover repo from file path', function()
      local filepath = repo .. '/file1.txt'
      local reponame, err = git_repo.discover(filepath)

      assert(not err)
      eq(reponame, repo)
    end)

    it('should discover repo from subdirectory file', function()
      test_repo.write_file(repo .. '/subdir/nested.txt', { 'nested' })

      local filepath = repo .. '/subdir/nested.txt'
      local reponame, err = git_repo.discover(filepath)

      assert(not err)
      eq(reponame, repo)
    end)

    it('should discover from cwd when filepath is nil', function()
      local reponame, err = git_repo.discover(nil)

      -- Should succeed if run from within a git repo, otherwise error
      if reponame then
        assert(not err, 'Should not error when repo found')
        assert(type(reponame) == 'string', 'Should return string path')
      else
        assert(err, 'Should error if not in a git repo')
      end
    end)

    it('should error on non-existent path', function()
      local reponame, err = git_repo.discover('/nonexistent/path/that/does/not/exist')

      assert(err)
      assert(not reponame)
    end)
  end)

  describe('dirname()', function()
    it('should return .git directory path', function()
      local git_dir, err = git_repo.dirname()

      assert(not err)
      assert(git_dir)
      assert(git_dir:match('%.git'))
    end)
  end)

  describe('exists()', function()
    it('should return true for repo directory', function()
      local exists = git_repo.exists(repo)

      eq(exists, true)
    end)

    it('should return true for file in repo', function()
      local filepath = repo .. '/file1.txt'
      local exists = git_repo.exists(filepath)

      eq(exists, true)
    end)

    it('should return true for subdirectory in repo', function()
      test_repo.write_file(repo .. '/subdir/file.txt', { 'content' })

      local filepath = repo .. '/subdir/file.txt'
      local exists = git_repo.exists(filepath)

      eq(exists, true)
    end)

    it('should return false for non-repo path', function()
      local exists = git_repo.exists('/nonexistent/path/that/does/not/exist')

      eq(exists, false)
    end)

    it('should use cwd when filepath is nil', function()
      local exists = git_repo.exists(nil)

      assert(exists ~= nil)
    end)
  end)

  describe('config()', function()
    it('should retrieve repository config', function()
      local config, err = git_repo.config(repo)

      assert(not err)
      assert(config)
      assert(#config > 0)
    end)

    it('should include core config values', function()
      local config, err = git_repo.config(repo)

      assert(not err)

      local config_str = table.concat(config, '\n')
      assert(config_str:match('core%.'))
    end)

    it('should error when reponame is missing', function()
      local config, err = git_repo.config(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not config)
    end)
  end)

  describe('has()', function()
    it('should return true for tracked file at HEAD', function()
      local has, err = git_repo.has(repo, 'file1.txt', 'HEAD')

      assert(not err)
      eq(has, true)
    end)

    it('should return true when commit is nil (defaults to HEAD)', function()
      local has, err = git_repo.has(repo, 'file1.txt', nil)

      assert(not err)
      eq(has, true)
    end)

    it('should return false for untracked file', function()
      test_repo.write_file(repo .. '/untracked.txt', { 'content' })

      local has, err = git_repo.has(repo, 'untracked.txt', 'HEAD')

      assert(not err)
      eq(has, false)
    end)

    it('should return false for nonexistent file', function()
      local has, err = git_repo.has(repo, 'nonexistent.txt', 'HEAD')

      assert(not err)
      eq(has, false)
    end)

    it('should work with files in subdirectories', function()
      test_repo.write_file(repo .. '/subdir/nested.txt', { 'nested' })
      test_repo.stage(repo, 'subdir/nested.txt')
      test_repo.create_commit(repo, {
        files = { ['subdir/nested.txt'] = { 'nested' } },
        message = 'Add nested file',
      })

      local has, err = git_repo.has(repo, 'subdir/nested.txt', 'HEAD')

      assert(not err)
      eq(has, true)
    end)

    it('should error when reponame is missing', function()
      local has, err = git_repo.has(nil, 'file1.txt', 'HEAD')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not has)
    end)

    it('should error when filename is missing', function()
      local has, err = git_repo.has(repo, nil, 'HEAD')

      assert(err)
      eq(err, { 'filename is required' })
      assert(not has)
    end)
  end)

  describe('ignores()', function()
    it('should return false for non-ignored file', function()
      local ignores, err = git_repo.ignores(repo, 'file1.txt')

      assert(not err)
      eq(ignores, false)
    end)

    it('should return true for ignored file', function()
      test_repo.write_file(repo .. '/.gitignore', { '*.log', 'temp/' })
      test_repo.write_file(repo .. '/test.log', { 'log content' })

      local ignores, err = git_repo.ignores(repo, 'test.log')

      assert(not err)
      eq(ignores, true)
    end)

    it('should return true for ignored directory', function()
      test_repo.write_file(repo .. '/.gitignore', { 'temp/' })
      test_repo.write_file(repo .. '/temp/file.txt', { 'content' })

      local ignores, err = git_repo.ignores(repo, 'temp/file.txt')

      assert(not err)
      eq(ignores, true)
    end)

    it('should handle wildcard patterns', function()
      test_repo.write_file(repo .. '/.gitignore', { '*.tmp' })
      test_repo.write_file(repo .. '/file.tmp', { 'temp' })

      local ignores, err = git_repo.ignores(repo, 'file.tmp')

      assert(not err)
      eq(ignores, true)
    end)

    it('should return false when no .gitignore exists', function()
      local ignores, err = git_repo.ignores(repo, 'anyfile.txt')

      assert(not err)
      eq(ignores, false)
    end)

    it('should error when reponame is missing', function()
      local ignores, err = git_repo.ignores(nil, 'file.txt')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not ignores)
    end)

    it('should error when filename is missing', function()
      local ignores, err = git_repo.ignores(repo, nil)

      assert(err)
      eq(err, { 'filename is required' })
      assert(not ignores)
    end)
  end)

  describe('checkout()', function()
    it('should checkout branch', function()
      test_repo.create_branch(repo, 'feature')

      local _, err = git_repo.checkout(repo, 'feature')

      assert(not err)
    end)

    it('should checkout commit by hash', function()
      local first_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file3.txt'] = { 'new' } },
        message = 'Second commit',
      })

      local _, err = git_repo.checkout(repo, first_commit)

      assert(not err)
    end)

    it('should checkout existing branch', function()
      test_repo.create_branch(repo, 'test-branch')
      test_repo.checkout(repo, 'master')

      local _, err = git_repo.checkout(repo, 'test-branch')

      assert(not err)
    end)

    it('should error when reponame is missing', function()
      local _, err = git_repo.checkout(nil, 'master')

      assert(err)
      eq(err, { 'reponame is required' })
    end)

    it('should error when name is missing', function()
      local _, err = git_repo.checkout(repo, nil)

      assert(err)
      eq(err, { 'name is required' })
    end)

    it('should error on nonexistent branch', function()
      local _, err = git_repo.checkout(repo, 'nonexistent-branch')

      assert(err)
    end)
  end)

  describe('reset()', function()
    it('should reset modified file', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      local _, err = git_repo.reset(repo, 'file1.txt')

      assert(not err)
    end)

    it('should reset all files when filename is nil', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified 1' })
      test_repo.modify_file(repo, 'file2.txt', { 'modified 2' })

      local _, err = git_repo.reset(repo, nil)

      assert(not err)
    end)

    it('should remove untracked files', function()
      test_repo.write_file(repo .. '/untracked.txt', { 'untracked' })

      local _, err = git_repo.reset(repo, nil)

      assert(not err)

      -- Untracked file should be removed
      local exists = vim.fn.filereadable(repo .. '/untracked.txt')
      eq(exists, 0)
    end)

    it('should reset specific file only', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified 1' })
      test_repo.modify_file(repo, 'file2.txt', { 'modified 2' })

      local _, err = git_repo.reset(repo, 'file1.txt')

      assert(not err)
    end)

    it('should handle subdirectory files', function()
      test_repo.write_file(repo .. '/subdir/file.txt', { 'original' })
      test_repo.stage(repo, 'subdir/file.txt')
      test_repo.create_commit(repo, {
        files = { ['subdir/file.txt'] = { 'original' } },
        message = 'Add subdir file',
      })

      test_repo.modify_file(repo, 'subdir/file.txt', { 'modified' })

      local _, err = git_repo.reset(repo, 'subdir/file.txt')

      assert(not err)
    end)

    it('should error when reponame is missing', function()
      local _, err = git_repo.reset(nil, 'file.txt')

      assert(err)
      eq(err, { 'reponame is required' })
    end)
  end)

  describe('clean()', function()
    it('should remove untracked files', function()
      test_repo.write_file(repo .. '/untracked.txt', { 'untracked' })

      local _, err = git_repo.clean(repo, nil)

      assert(not err)

      -- Untracked file should be removed
      local exists = vim.fn.filereadable(repo .. '/untracked.txt')
      eq(exists, 0)
    end)

    it('should remove untracked directories', function()
      test_repo.write_file(repo .. '/temp/file.txt', { 'temp' })

      local _, err = git_repo.clean(repo, nil)

      assert(not err)

      -- Untracked directory should be removed
      local exists = vim.fn.isdirectory(repo .. '/temp')
      eq(exists, 0)
    end)

    it('should clean specific file', function()
      test_repo.write_file(repo .. '/untracked1.txt', { 'content' })
      test_repo.write_file(repo .. '/untracked2.txt', { 'content' })

      local _, err = git_repo.clean(repo, 'untracked1.txt')

      assert(not err)

      -- untracked1.txt should be removed
      local exists1 = vim.fn.filereadable(repo .. '/untracked1.txt')
      eq(exists1, 0)
    end)

    it('should not remove tracked files', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      git_repo.clean(repo, nil)

      -- Tracked file should still exist
      local exists = vim.fn.filereadable(repo .. '/file1.txt')
      eq(exists, 1)
    end)

    it('should not remove staged files', function()
      test_repo.write_file(repo .. '/staged.txt', { 'content' })
      test_repo.stage(repo, 'staged.txt')

      git_repo.clean(repo, nil)

      -- Staged file should still exist
      local exists = vim.fn.filereadable(repo .. '/staged.txt')
      eq(exists, 1)
    end)

    it('should error when reponame is missing', function()
      local _, err = git_repo.clean(nil, nil)

      assert(err)
      eq(err, { 'reponame is required' })
    end)
  end)

  describe('integration scenarios', function()
    it('should handle reset after modifications', function()
      test_repo.modify_file(repo, 'file1.txt', { 'changed' })
      test_repo.write_file(repo .. '/new.txt', { 'new' })

      local _, err = git_repo.reset(repo, nil)

      assert(not err)
    end)

    it('should handle clean after adding untracked files', function()
      test_repo.write_file(repo .. '/temp1.txt', { 'temp' })
      test_repo.write_file(repo .. '/temp2.txt', { 'temp' })

      git_repo.clean(repo, nil)

      -- All untracked should be removed
      eq(vim.fn.filereadable(repo .. '/temp1.txt'), 0)
      eq(vim.fn.filereadable(repo .. '/temp2.txt'), 0)
    end)

    it('should verify file tracked status', function()
      test_repo.write_file(repo .. '/new.txt', { 'new file' })

      -- Not in HEAD yet (untracked)
      local has_before, err1 = git_repo.has(repo, 'new.txt', 'HEAD')
      assert(not err1)
      eq(has_before, false)

      -- file1.txt should exist (tracked)
      local has_tracked, err2 = git_repo.has(repo, 'file1.txt', 'HEAD')
      assert(not err2)
      eq(has_tracked, true)
    end)
  end)
end)
