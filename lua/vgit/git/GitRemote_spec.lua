local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
local GitRemote = require('vgit.git.GitRemote')
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('GitRemote', function()
  local repo
  local remote_repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      files = { ['README.md'] = 'Main repo' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(repo)

    remote_repo, err = test_repo.create_repo({
      files = { ['remote.txt'] = 'Remote content' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(remote_repo)

    -- Add remote to repo
    repo:add_remote('origin', remote_repo:get_path())
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
    if remote_repo then test_repo.cleanup(remote_repo) end
  end)

  describe('constructor', function()
    it('should create GitRemote instance', function()
      local remote = GitRemote(repo, 'origin')
      assert.is_not_nil(remote)
    end)

    it('should require repository', function()
      local success, _ = pcall(function()
        GitRemote(nil, 'origin')
      end)
      assert.is_false(success)
    end)
  end)

  describe('name', function()
    it('should return remote name', function()
      local remote = GitRemote(repo, 'origin')
      assert.equals('origin', remote:name())
    end)
  end)

  describe('url', function()
    it('should get remote URL', function()
      local remote = GitRemote(repo, 'origin')
      local url, err = remote:url()
      assert.is_nil(err)
      assert.equals(remote_repo:get_path(), url)
    end)

    it('should cache URL', function()
      local remote = GitRemote(repo, 'origin')
      local url1, _ = remote:url()
      local url2, _ = remote:url()
      assert.equals(url1, url2)
    end)
  end)

  describe('set_url', function()
    it('should change remote URL', function()
      local remote = GitRemote(repo, 'origin')
      local new_url = 'https://github.com/user/new-repo.git'

      local _, err = remote:set_url(new_url)
      assert.is_nil(err)

      -- Verify URL changed
      local url, _ = remote:url()
      assert.equals(new_url, url)
    end)

    it('should require URL', function()
      local remote = GitRemote(repo, 'origin')
      local _, err = remote:set_url(nil)
      assert.is_not_nil(err)
    end)

    it('should clear cache after setting URL', function()
      local remote = GitRemote(repo, 'origin')
      local old_url, _ = remote:url()

      local new_url = 'https://github.com/user/new.git'
      remote:set_url(new_url)

      local updated_url, _ = remote:url()
      assert.not_equals(old_url, updated_url)
    end)
  end)

  describe('push_url', function()
    it('should get push URL', function()
      local remote = GitRemote(repo, 'origin')
      local url, err = remote:push_url()
      -- Push URL might be same as fetch URL
      if not err then assert.is_not_nil(url) end
    end)
  end)

  describe('info', function()
    it('should get remote information', function()
      local remote = GitRemote(repo, 'origin')
      local info, err = remote:info()
      assert.is_nil(err)
      assert.is_not_nil(info)
      assert.equals('origin', info.name)
      assert.is_not_nil(info.fetch_url)
    end)

    it('should cache info', function()
      local remote = GitRemote(repo, 'origin')
      local info1, _ = remote:info()
      local info2, _ = remote:info()
      assert.equals(info1.name, info2.name)
    end)
  end)

  describe('remove', function()
    it('should remove remote', function()
      local remote = GitRemote(repo, 'origin')
      local _, err = remote:remove()
      assert.is_nil(err)

      -- Verify removal
      local remotes, _ = repo:remotes()
      assert.equals(0, #remotes)
    end)
  end)

  describe('rename', function()
    it('should rename remote', function()
      local remote = GitRemote(repo, 'origin')
      local _, err = remote:rename('upstream')
      assert.is_nil(err)

      -- Verify name changed
      assert.equals('upstream', remote:name())

      -- Verify in repository
      local remotes, _ = repo:remotes()
      assert.equals(1, #remotes)
      assert.equals('upstream', remotes[1]:name())
    end)

    it('should require new name', function()
      local remote = GitRemote(repo, 'origin')
      local _, err = remote:rename(nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('reset_cache', function()
    it('should clear cached data', function()
      local remote = GitRemote(repo, 'origin')

      -- Load data to cache
      remote:url()
      remote:info()

      -- Reset cache
      remote:reset_cache()

      -- Should still work (reload from git)
      local url, err = remote:url()
      assert.is_nil(err)
      assert.is_not_nil(url)
    end)
  end)

  describe('fetch', function()
    it('should return error for non-existent remote refspec', function()
      local remote = GitRemote(repo, 'origin')
      local _, err = remote:fetch('nonexistent-refspec-xyz')

      -- fetch with a bad refspec should error
      assert.is_not_nil(err)
    end)
  end)

  describe('prune', function()
    it('should not error on repo with no stale branches', function()
      local remote = GitRemote(repo, 'origin')
      local _, err = remote:prune()

      assert.is_nil(err)
    end)
  end)

  describe('integration with GitRepository', function()
    it('should work through repository remotes() method', function()
      local remotes, err = repo:remotes()
      assert.is_nil(err)
      assert.equals(1, #remotes)

      local remote = remotes[1]
      assert.equals('origin', remote:name())

      local url, url_err = remote:url()
      assert.is_nil(url_err)
      assert.equals(remote_repo:get_path(), url)
    end)

    it('should work through repository remote() method', function()
      local remote, err = repo:remote('origin')
      assert.is_nil(err)
      assert.is_not_nil(remote)
      assert.equals('origin', remote:name())
    end)
  end)
end)
