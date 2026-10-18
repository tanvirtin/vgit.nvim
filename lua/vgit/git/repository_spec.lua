local eq = assert.are.same

describe('repository:', function()
  local repository
  local original_git_repository

  before_each(function()
    original_git_repository = package.loaded['vgit.git.GitRepository']

    local mock_repo_instance = {
      reset = function() end,
    }

    package.loaded['vgit.git.GitRepository'] = {
      discover = function()
        return mock_repo_instance, nil
      end,
    }

    package.loaded['vgit.git.repository'] = nil
    repository = require('vgit.git.repository')
  end)

  after_each(function()
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
        if call_count == 1 then return nil, { 'error' } end
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

  describe('for_path', function()
    it('should discover from an existing path', function()
      local directory = vim.fn.tempname()
      vim.fn.mkdir(directory, 'p')
      local filepath = directory .. '/file.lua'
      vim.fn.writefile({ 'content' }, filepath)

      local discovered_path
      package.loaded['vgit.git.GitRepository'].discover = function(path)
        discovered_path = path
        return {}, nil
      end

      repository.for_path(filepath)

      eq(vim.fn.fnamemodify(filepath, ':p'), discovered_path)
      vim.fn.delete(directory, 'rf')
    end)

    it('should discover from the parent of a missing file', function()
      local directory = vim.fn.tempname()
      vim.fn.mkdir(directory, 'p')
      local filepath = directory .. '/deleted.lua'

      local discovered_path
      package.loaded['vgit.git.GitRepository'].discover = function(path)
        discovered_path = path
        return {}, nil
      end

      repository.for_path(filepath)

      local expected_path = vim.fn.fnamemodify(directory, ':p'):gsub('/+$', '')
      eq(expected_path, discovered_path)
      vim.fn.delete(directory, 'rf')
    end)

    it('should discover from the nearest existing ancestor of a missing nested path', function()
      local directory = vim.fn.tempname()
      vim.fn.mkdir(directory, 'p')
      local filepath = directory .. '/gone/deeper/deleted.lua'

      local discovered_path
      package.loaded['vgit.git.GitRepository'].discover = function(path)
        discovered_path = path
        return {}, nil
      end

      repository.for_path(filepath)

      local expected_path = vim.fn.fnamemodify(directory, ':p'):gsub('/+$', '')
      eq(expected_path, discovered_path)
      vim.fn.delete(directory, 'rf')
    end)

    it('should require a path', function()
      local repo, err = repository.for_path(nil)

      assert.is_nil(repo)
      eq({ 'path is required' }, err)
    end)
  end)

  describe('switch', function()
    local original_fs
    local original_git_repo

    before_each(function()
      original_fs = package.loaded['vgit.core.fs']
      original_git_repo = package.loaded['vgit.git.git_repo']
    end)

    after_each(function()
      package.loaded['vgit.core.fs'] = original_fs
      package.loaded['vgit.git.git_repo'] = original_git_repo
    end)

    it('should drop caches before changing directory', function()
      local order = {}
      package.loaded['vgit.git.git_repo'] = {
        clear_cache = function()
          order[#order + 1] = 'clear_cache:' .. tostring(repository.is_loaded())
        end,
      }
      package.loaded['vgit.core.fs'] = {
        chdir = function(path)
          order[#order + 1] = 'chdir:' .. path
        end,
      }
      package.loaded['vgit.git.repository'] = nil
      repository = require('vgit.git.repository')
      repository.current()

      repository.switch('/some/worktree')

      eq({ 'clear_cache:false', 'chdir:/some/worktree' }, order)
    end)
  end)

  describe('invalidate', function()
    it('should clear the cached instance', function()
      repository.current()
      assert.is_true(repository.is_loaded())

      repository.invalidate()

      assert.is_false(repository.is_loaded())
      assert.is_nil(repository.get_cached())
    end)

    it('should clear the cache', function()
      repository.current()
      assert.is_true(repository.is_loaded())

      repository.invalidate()
      assert.is_false(repository.is_loaded())
      assert.is_nil(repository.get_cached())
    end)

    it('should do nothing when no instance is cached', function()
      repository.invalidate()

      assert.is_false(repository.is_loaded())
    end)

    it('should allow current() to create a new instance after invalidate', function()
      local repo1 = repository.current()
      repository.invalidate()

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
