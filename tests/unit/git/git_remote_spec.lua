local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local git_remote = require('vgit.git.git_remote')

describe('git_remote', function()
  local repo
  local remote_repo

  before_each(function()
    -- Create main test repository
    local err
    repo, err = test_repo.create_repo({
      files = { ['README.md'] = 'Test repo' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(repo)

    -- Create a "remote" repository
    remote_repo, err = test_repo.create_repo({
      files = { ['remote.txt'] = 'Remote content' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(remote_repo)
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
    if remote_repo then test_repo.cleanup(remote_repo) end
  end)

  describe('add', function()
    it('should add a new remote', function()
      local _, err = git_remote.add(repo:get_path(), 'origin', remote_repo:get_path())
      assert.is_nil(err)

      -- Verify remote was added
      local remotes, list_err = git_remote.list(repo:get_path())
      assert.is_nil(list_err)
      assert.is_not_nil(remotes)
      assert.equals(1, #remotes)
      assert.equals('origin', remotes[1].name)
    end)

    it('should add remote with options', function()
      local _, err = git_remote.add(repo:get_path(), 'upstream', remote_repo:get_path(), {
        tags = false,
      })
      assert.is_nil(err)

      local remotes, _ = git_remote.list(repo:get_path())
      assert.equals(1, #remotes)
      assert.equals('upstream', remotes[1].name)
    end)

    it('should return error for missing parameters', function()
      local _, err = git_remote.add(nil, 'origin', 'url')
      assert.is_not_nil(err)

      _, err = git_remote.add(repo:get_path(), nil, 'url')
      assert.is_not_nil(err)

      _, err = git_remote.add(repo:get_path(), 'origin', nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('list', function()
    before_each(function()
      git_remote.add(repo:get_path(), 'origin', remote_repo:get_path())
      git_remote.add(repo:get_path(), 'upstream', remote_repo:get_path())
    end)

    it('should list remote names', function()
      local remotes, err = git_remote.list(repo:get_path())
      assert.is_nil(err)
      assert.equals(2, #remotes)

      local names = {}
      for _, remote in ipairs(remotes) do
        table.insert(names, remote.name)
      end
      table.sort(names)

      assert.equals('origin', names[1])
      assert.equals('upstream', names[2])
    end)

    it('should list remotes with URLs when verbose', function()
      local remotes, err = git_remote.list(repo:get_path(), { verbose = true })
      assert.is_nil(err)
      assert.equals(2, #remotes)

      for _, remote in ipairs(remotes) do
        assert.is_not_nil(remote.name)
        assert.is_not_nil(remote.fetch_url)
      end
    end)

    it('should return empty list for repo with no remotes', function()
      local new_repo, err = test_repo.create_repo({ initial_commit = true })
      assert.is_nil(err)

      local remotes, list_err = git_remote.list(new_repo:get_path())
      assert.is_nil(list_err)
      assert.equals(0, #remotes)

      test_repo.cleanup(new_repo)
    end)
  end)

  describe('get_url', function()
    before_each(function()
      git_remote.add(repo:get_path(), 'origin', remote_repo:get_path())
    end)

    it('should get remote URL', function()
      local url, err = git_remote.get_url(repo:get_path(), 'origin')
      assert.is_nil(err)
      assert.equals(remote_repo:get_path(), url)
    end)

    it('should return error for non-existent remote', function()
      local _, err = git_remote.get_url(repo:get_path(), 'nonexistent')
      assert.is_not_nil(err)
    end)
  end)

  describe('remove', function()
    before_each(function()
      git_remote.add(repo:get_path(), 'origin', remote_repo:get_path())
    end)

    it('should remove a remote', function()
      local _, err = git_remote.remove(repo:get_path(), 'origin')
      assert.is_nil(err)

      -- Verify removal
      local remotes, _ = git_remote.list(repo:get_path())
      assert.equals(0, #remotes)
    end)

    it('should return error for non-existent remote', function()
      local _, err = git_remote.remove(repo:get_path(), 'nonexistent')
      assert.is_not_nil(err)
    end)
  end)

  describe('rename', function()
    before_each(function()
      git_remote.add(repo:get_path(), 'origin', remote_repo:get_path())
    end)

    it('should rename a remote', function()
      local _, err = git_remote.rename(repo:get_path(), 'origin', 'upstream')
      assert.is_nil(err)

      -- Verify rename
      local remotes, _ = git_remote.list(repo:get_path())
      assert.equals(1, #remotes)
      assert.equals('upstream', remotes[1].name)
    end)
  end)

  describe('set_url', function()
    before_each(function()
      git_remote.add(repo:get_path(), 'origin', remote_repo:get_path())
    end)

    it('should change remote URL', function()
      local new_url = 'https://github.com/user/new-repo.git'
      local _, err = git_remote.set_url(repo:get_path(), 'origin', new_url)
      assert.is_nil(err)

      -- Verify URL changed
      local url, _ = git_remote.get_url(repo:get_path(), 'origin')
      assert.equals(new_url, url)
    end)
  end)

  describe('show', function()
    before_each(function()
      git_remote.add(repo:get_path(), 'origin', remote_repo:get_path())
    end)

    it('should show remote information', function()
      local info, err = git_remote.show(repo:get_path(), 'origin')
      assert.is_nil(err)
      assert.is_not_nil(info)
      assert.equals('origin', info.name)
      assert.is_not_nil(info.fetch_url)
    end)
  end)
end)
