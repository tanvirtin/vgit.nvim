local eq = assert.are.same

local function fake_repo(path)
  return {
    get_path = function()
      return path or '/repo'
    end,
  }
end

describe('repository:', function()
  local repository
  local original_git_repository

  before_each(function()
    original_git_repository = package.loaded['vgit.git.GitRepository']

    local mock_repo_instance = fake_repo()

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
        return fake_repo(), nil
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
        return fake_repo(), nil
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

  describe('current with a file open', function()
    local directory
    local filepath

    before_each(function()
      directory = vim.fn.resolve(vim.fn.tempname())
      vim.fn.mkdir(directory, 'p')
      filepath = directory .. '/file.lua'
      vim.fn.writefile({ 'content' }, filepath)
      vim.cmd.edit(filepath)
    end)

    after_each(function()
      vim.cmd('silent! %bwipeout!')
      vim.fn.delete(directory, 'rf')
    end)

    it('should use the repo of the current file', function()
      package.loaded['vgit.git.GitRepository'].discover = function(path)
        if path then return fake_repo('/file-repo'), nil end
        return fake_repo('/cwd-repo'), nil
      end

      local repo = repository.current()

      eq('/file-repo', repo:get_path())
    end)

    it('should fall back to the working directory when the file is outside a repo', function()
      package.loaded['vgit.git.GitRepository'].discover = function(path)
        if path then return nil, { 'not a git repository' } end
        return fake_repo('/cwd-repo'), nil
      end

      local repo = repository.current()

      eq('/cwd-repo', repo:get_path())
    end)

    it('should ignore buffers that are not files', function()
      vim.bo.buftype = 'nofile'
      package.loaded['vgit.git.GitRepository'].discover = function(path)
        if path then return fake_repo('/file-repo'), nil end
        return fake_repo('/cwd-repo'), nil
      end

      local repo = repository.current()

      eq('/cwd-repo', repo:get_path())
    end)

    it('should return the same instance for the same repo', function()
      package.loaded['vgit.git.GitRepository'].discover = function()
        return fake_repo('/file-repo'), nil
      end

      local repo1 = repository.current()
      local repo2 = repository.current()

      assert.are.equal(repo1, repo2)
    end)

    it('should remember the last repo it resolved', function()
      package.loaded['vgit.git.GitRepository'].discover = function()
        return fake_repo('/file-repo'), nil
      end

      local repo = repository.current()

      assert.are.equal(repo, repository.get_cached())
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
        return fake_repo(), nil
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
        return fake_repo(), nil
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
        return fake_repo(), nil
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

  describe('list', function()
    local cwd
    local directory
    local root
    local git_setting = require('vgit.settings.git')
    local defaults

    local function paths()
      return vim.tbl_map(function(repo)
        return repo:get_path()
      end, repository.list())
    end

    local function make_repo(path)
      vim.fn.mkdir(directory .. '/' .. path .. '/.git', 'p')
    end

    before_each(function()
      cwd = vim.uv.cwd()
      defaults = vim.deepcopy(git_setting.data)
      directory = vim.fn.tempname()
      vim.fn.mkdir(directory, 'p')
      vim.fn.chdir(directory)
      root = vim.uv.cwd()

      package.loaded['vgit.git.GitRepository'].discover = function()
        return nil, { 'not a git repository' }
      end
      package.loaded['vgit.git.GitRepository'].at = fake_repo
    end)

    after_each(function()
      git_setting.data = defaults
      vim.cmd('silent! %bwipeout!')
      vim.fn.chdir(cwd)
      vim.fn.delete(directory, 'rf')
    end)

    it('should list the repos in the child folders of a folder that is not a repo', function()
      make_repo('beta')
      make_repo('node_modules/pkg')
      vim.fn.mkdir(directory .. '/plain', 'p')
      vim.fn.mkdir(directory .. '/alpha', 'p')
      vim.fn.writefile({ 'gitdir: elsewhere' }, directory .. '/alpha/.git')

      eq({ root .. '/alpha', root .. '/beta' }, paths())
    end)

    it('should scan as many folder levels as repository_scan_max_depth', function()
      make_repo('org/deep')
      eq({}, paths())

      git_setting:assign({ repository_scan_max_depth = 2 })
      eq({ root .. '/org/deep' }, paths())
    end)

    it('should skip the folders in repository_scan_ignored_folders', function()
      make_repo('vendor')
      make_repo('node_modules')
      git_setting:assign({ repository_scan_ignored_folders = { 'vendor' } })

      eq({ root .. '/node_modules' }, paths())
    end)

    it('should list the repos of open buffers', function()
      vim.fn.mkdir(directory .. '/elsewhere/project/.git', 'p')
      vim.fn.writefile({ 'x' }, directory .. '/elsewhere/project/file.txt')
      vim.cmd('badd ' .. vim.fn.fnameescape(directory .. '/elsewhere/project/file.txt'))

      eq({ root .. '/elsewhere/project' }, paths())
    end)

    it('should follow auto_repository_detection', function()
      make_repo('child')
      vim.fn.mkdir(directory .. '/elsewhere/project/.git', 'p')
      vim.fn.writefile({ 'x' }, directory .. '/elsewhere/project/file.txt')
      vim.cmd('badd ' .. vim.fn.fnameescape(directory .. '/elsewhere/project/file.txt'))

      git_setting:assign({ auto_repository_detection = 'sub_folders' })
      eq({ root .. '/child' }, paths())

      git_setting:assign({ auto_repository_detection = 'open_buffers' })
      eq({ root .. '/elsewhere/project' }, paths())

      git_setting:assign({ auto_repository_detection = false })
      eq({}, paths())
    end)

    it('should list a repo once when the folder and a child resolve to it', function()
      make_repo('child')
      package.loaded['vgit.git.GitRepository'].discover = function()
        return fake_repo(root .. '/child'), nil
      end

      eq(1, #repository.list())
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
        git_dir = function() end,
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

      local new_mock = fake_repo()
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
