local eq = assert.are.same

describe('repository', function()
  local repository
  local original_git_repository

  before_each(function()
    -- Save original and clear cached modules
    original_git_repository = package.loaded['vgit.git.GitRepository']

    -- Create a mock GitRepository
    local mock_repo_instance = {
      reset = function() end,
    }

    package.loaded['vgit.git.GitRepository'] = {
      discover = function()
        return mock_repo_instance, nil
      end,
    }

    -- Clear and re-require repository to pick up the mock
    package.loaded['vgit.git.repository'] = nil
    repository = require('vgit.git.repository')
  end)

  after_each(function()
    -- Restore original module
    package.loaded['vgit.git.GitRepository'] = original_git_repository
    package.loaded['vgit.git.repository'] = nil
  end)

  describe('is_loaded', function()
    it('should return false initially', function()
      assert.is_false(repository.is_loaded())
    end)

    it('should return true after current() is called', function()
      repository.current()

      assert.is_true(repository.is_loaded())
    end)

    it('should return false after invalidate()', function()
      repository.current()
      repository.invalidate()

      assert.is_false(repository.is_loaded())
    end)
  end)

  describe('get_cached', function()
    it('should return nil initially', function()
      assert.is_nil(repository.get_cached())
    end)

    it('should return the instance after current()', function()
      local repo = repository.current()

      eq(repo, repository.get_cached())
    end)

    it('should return nil after invalidate()', function()
      repository.current()
      repository.invalidate()

      assert.is_nil(repository.get_cached())
    end)
  end)

  describe('current', function()
    it('should call GitRepository.discover()', function()
      local discover_called = false

      package.loaded['vgit.git.GitRepository'].discover = function()
        discover_called = true
        return { reset = function() end }, nil
      end

      -- Re-require to pick up the new mock
      package.loaded['vgit.git.repository'] = nil
      repository = require('vgit.git.repository')

      repository.current()

      assert.is_true(discover_called)
    end)

    it('should return an instance', function()
      local repo, err = repository.current()

      assert.is_not_nil(repo)
      assert.is_nil(err)
    end)

    it('should cache on second call (returns same instance)', function()
      local repo1 = repository.current()
      local repo2 = repository.current()

      assert.are.equal(repo1, repo2)
    end)

    it('should propagate error from GitRepository.discover()', function()
      package.loaded['vgit.git.GitRepository'].discover = function()
        return nil, { 'not a git repo' }
      end

      package.loaded['vgit.git.repository'] = nil
      repository = require('vgit.git.repository')

      local repo, err = repository.current()

      assert.is_nil(repo)
      eq({ 'not a git repo' }, err)
    end)

    it('should not cache after error', function()
      local call_count = 0
      package.loaded['vgit.git.GitRepository'].discover = function()
        call_count = call_count + 1
        if call_count == 1 then
          return nil, { 'error' }
        end
        return { reset = function() end }, nil
      end

      package.loaded['vgit.git.repository'] = nil
      repository = require('vgit.git.repository')

      local repo1, err1 = repository.current()
      assert.is_nil(repo1)
      assert.is_not_nil(err1)

      local repo2, err2 = repository.current()
      assert.is_not_nil(repo2)
      assert.is_nil(err2)
    end)
  end)

  describe('invalidate', function()
    it('should call reset on the cached instance', function()
      local reset_called = false
      local mock_repo = {
        reset = function()
          reset_called = true
        end,
      }

      package.loaded['vgit.git.GitRepository'].discover = function()
        return mock_repo, nil
      end

      package.loaded['vgit.git.repository'] = nil
      repository = require('vgit.git.repository')

      repository.current()
      repository.invalidate()

      assert.is_true(reset_called)
    end)

    it('should clear the cache', function()
      repository.current()
      assert.is_true(repository.is_loaded())

      repository.invalidate()
      assert.is_false(repository.is_loaded())
      assert.is_nil(repository.get_cached())
    end)

    it('should do nothing when no instance is cached', function()
      -- Should not error
      repository.invalidate()

      assert.is_false(repository.is_loaded())
    end)

    it('should allow current() to create a new instance after invalidate', function()
      local repo1 = repository.current()
      repository.invalidate()

      -- Create new mock to ensure different instance
      local new_mock = { reset = function() end }
      package.loaded['vgit.git.GitRepository'].discover = function()
        return new_mock, nil
      end

      package.loaded['vgit.git.repository'] = nil
      repository = require('vgit.git.repository')

      local repo2 = repository.current()

      assert.is_not_nil(repo2)
      assert.are.equal(new_mock, repo2)
    end)
  end)
end)
