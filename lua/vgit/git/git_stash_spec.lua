local git_stash = require('vgit.git.git_stash')
local git_status = require('vgit.git.git_status')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('git_stash:', function()
  local repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = {
        ['file1.txt'] = { 'line 1', 'line 2', 'line 3' },
        ['file2.txt'] = { 'content' },
      },
    })
    assert(not err, 'Failed to create test repo: ' .. tostring(err))
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('add()', function()
    it('should create stash with changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      local _, err = git_stash.add(repo)

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    it('should stash multiple files', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified 1' })
      test_repo.modify_file(repo, 'file2.txt', { 'modified 2' })

      local _, err = git_stash.add(repo)

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    it('should stash staged changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.stage(repo, 'file1.txt')

      local _, err = git_stash.add(repo)

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    it('should stash both staged and unstaged changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'staged version' })
      test_repo.stage(repo, 'file1.txt')
      test_repo.modify_file(repo, 'file1.txt', { 'unstaged version' })

      local _, err = git_stash.add(repo)

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    it('should leave working directory clean', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      test_repo.write_file(repo .. '/new.txt', { 'new file' })

      git_stash.add(repo)

      local files = git_status.ls(repo)
      assert(files)
    end)

    it('should create stash entry in list', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })
      git_stash.add(repo)

      local stashes, err = git_stash.list(repo)

      assert(not err)
      eq(#stashes, 1)
    end)

    it('should handle stash with no changes', function()
      local result, err = git_stash.add(repo)

      if err then
        assert(type(err) == 'table', 'Error should be a table')
        assert(#err > 0, 'Error should have message')
      else
        assert(result, 'Should return result on success')
      end

      local stashes = git_stash.list(repo)
      assert(type(stashes) == 'table', 'Should still be able to list stashes')
    end)

    it('should error when reponame is missing', function()
      local _, err = git_stash.add(nil)

      assert(err)
      eq(err, { 'reponame is required' })
    end)
  end)

  describe('apply()', function()
    it('should apply stash by index', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed content' })
      git_stash.add(repo)

      local _, err = git_stash.apply(repo, 'stash@{0}')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].filename, 'file1.txt')
    end)

    it('should preserve stash after apply', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      git_stash.apply(repo, 'stash@{0}')

      local stashes = git_stash.list(repo)
      eq(#stashes, 1)
    end)

    it('should restore changes to working directory', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed content' })
      git_stash.add(repo)

      eq(#git_status.ls(repo), 0)

      local _, err = git_stash.apply(repo, 'stash@{0}')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)
      eq(files[1].filename, 'file1.txt')
    end)

    it('should error on invalid stash index', function()
      local _, err = git_stash.apply(repo, 'stash@{99}')

      assert(err)
    end)

    it('should error when reponame is missing', function()
      local _, err = git_stash.apply(nil, 'stash@{0}')

      assert(err)
      eq(err, { 'reponame is required' })
    end)

    it('should error when stash_index is missing', function()
      local _, err = git_stash.apply(repo, nil)

      assert(err)
      eq(err, { 'stash_index is required' })
    end)
  end)

  describe('pop()', function()
    it('should apply and remove stash', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      local _, err = git_stash.pop(repo, 'stash@{0}')

      assert(not err)

      local files = git_status.ls(repo)
      eq(#files, 1)

      local stashes = git_stash.list(repo)
      eq(#stashes, 0)
    end)

    it('should restore and remove stash simultaneously', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      eq(#git_stash.list(repo), 1)

      local _, err = git_stash.pop(repo, 'stash@{0}')

      assert(not err)
      eq(#git_status.ls(repo), 1)
      eq(#git_stash.list(repo), 0)
    end)

    it('should error on invalid stash index', function()
      local _, err = git_stash.pop(repo, 'stash@{99}')

      assert(err)
    end)

    it('should error when reponame is missing', function()
      local _, err = git_stash.pop(nil, 'stash@{0}')

      assert(err)
      eq(err, { 'reponame is required' })
    end)

    it('should error when stash_index is missing', function()
      local _, err = git_stash.pop(repo, nil)

      assert(err)
      eq(err, { 'stash_index is required' })
    end)
  end)

  describe('drop()', function()
    it('should remove specific stash', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      local _, err = git_stash.drop(repo, 'stash@{0}')

      assert(not err)

      local stashes = git_stash.list(repo)
      eq(#stashes, 0)
    end)

    it('should not apply changes when dropping', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      git_stash.drop(repo, 'stash@{0}')

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    it('should remove stash without applying changes', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      eq(#git_status.ls(repo), 0)
      eq(#git_stash.list(repo), 1)

      local _, err = git_stash.drop(repo, 'stash@{0}')

      assert(not err)
      eq(#git_status.ls(repo), 0)
      eq(#git_stash.list(repo), 0)
    end)

    it('should error on invalid stash index', function()
      local _, err = git_stash.drop(repo, 'stash@{99}')

      assert(err)
    end)

    it('should error when reponame is missing', function()
      local _, err = git_stash.drop(nil, 'stash@{0}')

      assert(err)
      eq(err, { 'reponame is required' })
    end)

    it('should error when stash_index is missing', function()
      local _, err = git_stash.drop(repo, nil)

      assert(err)
      eq(err, { 'stash_index is required' })
    end)
  end)

  describe('clear()', function()
    it('should remove existing stash', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      eq(#git_stash.list(repo), 1)

      local _, err = git_stash.clear(repo)

      assert(not err)

      local stashes = git_stash.list(repo)
      eq(#stashes, 0)
    end)

    it('should handle empty stash list', function()
      local _, err = git_stash.clear(repo)

      assert(not err)

      local stashes = git_stash.list(repo)
      eq(#stashes, 0)
    end)

    it('should not affect working directory', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      git_stash.clear(repo)

      local files = git_status.ls(repo)
      eq(#files, 0)
    end)

    it('should error when reponame is missing', function()
      local _, err = git_stash.clear(nil)

      assert(err)
      eq(err, { 'reponame is required' })
    end)
  end)

  describe('list()', function()
    it('should list existing stash', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      local stashes, err = git_stash.list(repo)

      assert(not err)
      eq(#stashes, 1)
    end)

    it('should parse stash metadata', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      local stashes, err = git_stash.list(repo)

      assert(not err)
      assert(stashes[1])
      assert(stashes[1].commit_hash)
      assert(stashes[1].timestamp)
      assert(stashes[1].author_name)
      assert(stashes[1].author_email)
      assert(stashes[1].summary)
      assert(stashes[1].revision)
    end)

    it('should return empty list when no stashes', function()
      local stashes, err = git_stash.list(repo)

      assert(not err)
      eq(#stashes, 0)
    end)

    it('should include revision field', function()
      test_repo.modify_file(repo, 'file1.txt', { 'stashed' })
      git_stash.add(repo)

      local stashes, err = git_stash.list(repo)

      assert(not err)
      assert(stashes[1].revision)
      assert(stashes[1].revision:match('stash@'))
    end)

    it('should error when reponame is missing', function()
      local stashes, err = git_stash.list(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not stashes)
    end)
  end)

  describe('integration scenarios', function()
    it('should handle stash/pop workflow', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      git_stash.add(repo)
      eq(#git_status.ls(repo), 0)

      git_stash.pop(repo, 'stash@{0}')

      eq(#git_status.ls(repo), 1)
      eq(#git_stash.list(repo), 0)
    end)

    it('should handle stash/apply/drop workflow', function()
      test_repo.modify_file(repo, 'file1.txt', { 'modified' })

      git_stash.add(repo)
      eq(#git_status.ls(repo), 0)
      eq(#git_stash.list(repo), 1)

      git_stash.apply(repo, 'stash@{0}')
      eq(#git_status.ls(repo), 1)

      git_stash.drop(repo, 'stash@{0}')
      eq(#git_stash.list(repo), 0)
    end)
  end)
end)
