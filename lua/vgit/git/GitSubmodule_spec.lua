local GitSubmodule = require('vgit.git.GitSubmodule')
local git_submodule = require('vgit.git.git_submodule')

local eq = assert.are.same

local function make_repo(path)
  path = path or '/repo'
  return { get_path = function() return path end }
end

local mock_submodules = {
  { path = 'libs/foo', hash = 'abc123', ref = 'v1.0', status = 'initialized' },
  { path = 'libs/bar', hash = 'def456', ref = nil, status = 'uninitialized' },
  { path = 'libs/baz', hash = 'ghi789', ref = 'main', status = 'modified' },
  { path = 'libs/qux', hash = 'jkl012', ref = nil, status = 'conflicts' },
}

describe('GitSubmodule', function()
  local originals = {}

  before_each(function()
    originals.list = git_submodule.list
    originals.init = git_submodule.init
    originals.deinit = git_submodule.deinit
    originals.update = git_submodule.update
    originals.sync = git_submodule.sync
    originals.set_branch = git_submodule.set_branch
    originals.set_url = git_submodule.set_url

    git_submodule.list = function()
      return vim.deepcopy(mock_submodules), nil
    end
    git_submodule.init = function() return {}, nil end
    git_submodule.deinit = function() return {}, nil end
    git_submodule.update = function() return {}, nil end
    git_submodule.sync = function() return {}, nil end
    git_submodule.set_branch = function() return {}, nil end
    git_submodule.set_url = function() return {}, nil end
  end)

  after_each(function()
    git_submodule.list = originals.list
    git_submodule.init = originals.init
    git_submodule.deinit = originals.deinit
    git_submodule.update = originals.update
    git_submodule.sync = originals.sync
    git_submodule.set_branch = originals.set_branch
    git_submodule.set_url = originals.set_url
  end)

  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitSubmodule(nil, 'libs/foo')
      end, 'GitSubmodule requires a repository')
    end)

    it('should error when path is nil', function()
      assert.has_error(function()
        GitSubmodule(make_repo(), nil)
      end, 'GitSubmodule requires a path')
    end)

    it('should create instance with valid args', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')

      assert.is_not_nil(sub)
      eq('/repo', sub._repo_path)
      eq('libs/foo', sub._path)
      assert.is_nil(sub._info)
    end)
  end)

  describe('path()', function()
    it('should return the path', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')

      eq('libs/foo', sub:path())
    end)
  end)

  describe('info()', function()
    it('should find matching submodule from list', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local info, err = sub:info()

      assert.is_nil(err)
      eq('libs/foo', info.path)
      eq('abc123', info.hash)
      eq('v1.0', info.ref)
      eq('initialized', info.status)
    end)

    it('should cache result after first call', function()
      local call_count = 0
      git_submodule.list = function()
        call_count = call_count + 1
        return vim.deepcopy(mock_submodules), nil
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      sub:info()
      sub:info()

      eq(1, call_count)
    end)

    it('should return error when submodule not found', function()
      local sub = GitSubmodule(make_repo(), 'nonexistent/path')
      local info, err = sub:info()

      assert.is_nil(info)
      assert.is_not_nil(err)
      eq({ 'submodule not found: nonexistent/path' }, err)
    end)

    it('should propagate list error', function()
      git_submodule.list = function()
        return nil, { 'git error' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local info, err = sub:info()

      assert.is_nil(info)
      eq({ 'git error' }, err)
    end)
  end)

  describe('status()', function()
    it('should return status string', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local status, err = sub:status()

      assert.is_nil(err)
      eq('initialized', status)
    end)

    it('should return uninitialized status', function()
      local sub = GitSubmodule(make_repo(), 'libs/bar')
      local status, err = sub:status()

      assert.is_nil(err)
      eq('uninitialized', status)
    end)

    it('should propagate error', function()
      git_submodule.list = function()
        return nil, { 'status error' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local status, err = sub:status()

      assert.is_nil(status)
      eq({ 'status error' }, err)
    end)
  end)

  describe('hash()', function()
    it('should return hash', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local hash, err = sub:hash()

      assert.is_nil(err)
      eq('abc123', hash)
    end)

    it('should propagate error', function()
      git_submodule.list = function()
        return nil, { 'hash error' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local hash, err = sub:hash()

      assert.is_nil(hash)
      eq({ 'hash error' }, err)
    end)
  end)

  describe('ref()', function()
    it('should return ref', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local ref, err = sub:ref()

      assert.is_nil(err)
      eq('v1.0', ref)
    end)

    it('should return nil ref when submodule has no ref', function()
      local sub = GitSubmodule(make_repo(), 'libs/bar')
      local ref, err = sub:ref()

      assert.is_nil(err)
      assert.is_nil(ref)
    end)

    it('should propagate error', function()
      git_submodule.list = function()
        return nil, { 'ref error' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local ref, err = sub:ref()

      assert.is_nil(ref)
      eq({ 'ref error' }, err)
    end)
  end)

  describe('init()', function()
    it('should delegate to git_submodule.init with correct args', function()
      local captured_repo, captured_path
      git_submodule.init = function(repo_path, path)
        captured_repo = repo_path
        captured_path = path
        return {}, nil
      end

      local sub = GitSubmodule(make_repo('/my/repo'), 'libs/foo')
      local result, err = sub:init()

      assert.is_nil(err)
      eq(true, result)
      eq('/my/repo', captured_repo)
      eq('libs/foo', captured_path)
    end)

    it('should invalidate cache after success', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:init()
      assert.is_nil(sub._info)
    end)

    it('should propagate error', function()
      git_submodule.init = function()
        return nil, { 'init failed' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:init()

      assert.is_nil(result)
      eq({ 'init failed' }, err)
    end)

    it('should not invalidate cache on error', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      git_submodule.init = function()
        return nil, { 'init failed' }
      end

      sub:init()
      assert.is_not_nil(sub._info)
    end)
  end)

  describe('deinit()', function()
    it('should delegate to git_submodule.deinit with correct args', function()
      local captured_repo, captured_path, captured_opts
      git_submodule.deinit = function(repo_path, path, opts)
        captured_repo = repo_path
        captured_path = path
        captured_opts = opts
        return {}, nil
      end

      local sub = GitSubmodule(make_repo('/my/repo'), 'libs/foo')
      local opts = { force = true }
      local result, err = sub:deinit(opts)

      assert.is_nil(err)
      eq(true, result)
      eq('/my/repo', captured_repo)
      eq('libs/foo', captured_path)
      eq(opts, captured_opts)
    end)

    it('should invalidate cache after success', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:deinit()
      assert.is_nil(sub._info)
    end)

    it('should propagate error', function()
      git_submodule.deinit = function()
        return nil, { 'deinit failed' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:deinit()

      assert.is_nil(result)
      eq({ 'deinit failed' }, err)
    end)
  end)

  describe('update()', function()
    it('should delegate to git_submodule.update with correct args', function()
      local captured_repo, captured_path, captured_opts
      git_submodule.update = function(repo_path, path, opts)
        captured_repo = repo_path
        captured_path = path
        captured_opts = opts
        return {}, nil
      end

      local sub = GitSubmodule(make_repo('/my/repo'), 'libs/foo')
      local opts = { init = true, recursive = true }
      local result, err = sub:update(opts)

      assert.is_nil(err)
      eq(true, result)
      eq('/my/repo', captured_repo)
      eq('libs/foo', captured_path)
      eq(opts, captured_opts)
    end)

    it('should invalidate cache after success', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:update()
      assert.is_nil(sub._info)
    end)

    it('should propagate error', function()
      git_submodule.update = function()
        return nil, { 'update failed' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:update()

      assert.is_nil(result)
      eq({ 'update failed' }, err)
    end)
  end)

  describe('sync()', function()
    it('should delegate to git_submodule.sync with correct args', function()
      local captured_repo, captured_path, captured_opts
      git_submodule.sync = function(repo_path, path, opts)
        captured_repo = repo_path
        captured_path = path
        captured_opts = opts
        return {}, nil
      end

      local sub = GitSubmodule(make_repo('/my/repo'), 'libs/foo')
      local opts = { recursive = true }
      local result, err = sub:sync(opts)

      assert.is_nil(err)
      eq(true, result)
      eq('/my/repo', captured_repo)
      eq('libs/foo', captured_path)
      eq(opts, captured_opts)
    end)

    it('should invalidate cache after success', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:sync()
      assert.is_nil(sub._info)
    end)

    it('should propagate error', function()
      git_submodule.sync = function()
        return nil, { 'sync failed' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:sync()

      assert.is_nil(result)
      eq({ 'sync failed' }, err)
    end)
  end)

  describe('set_branch()', function()
    it('should delegate to git_submodule.set_branch with correct args', function()
      local captured_repo, captured_branch, captured_path, captured_opts
      git_submodule.set_branch = function(repo_path, branch, path, opts)
        captured_repo = repo_path
        captured_branch = branch
        captured_path = path
        captured_opts = opts
        return {}, nil
      end

      local sub = GitSubmodule(make_repo('/my/repo'), 'libs/foo')
      local opts = { default = false }
      local result, err = sub:set_branch('develop', opts)

      assert.is_nil(err)
      eq(true, result)
      eq('/my/repo', captured_repo)
      eq('develop', captured_branch)
      eq('libs/foo', captured_path)
      eq(opts, captured_opts)
    end)

    it('should invalidate cache after success', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:set_branch('main')
      assert.is_nil(sub._info)
    end)

    it('should propagate error', function()
      git_submodule.set_branch = function()
        return nil, { 'set_branch failed' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:set_branch('main')

      assert.is_nil(result)
      eq({ 'set_branch failed' }, err)
    end)
  end)

  describe('set_url()', function()
    it('should validate url is required', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:set_url(nil)

      assert.is_nil(result)
      eq({ 'url is required' }, err)
    end)

    it('should delegate to git_submodule.set_url with correct args', function()
      local captured_repo, captured_path, captured_url
      git_submodule.set_url = function(repo_path, path, url)
        captured_repo = repo_path
        captured_path = path
        captured_url = url
        return {}, nil
      end

      local sub = GitSubmodule(make_repo('/my/repo'), 'libs/foo')
      local result, err = sub:set_url('https://github.com/example/repo.git')

      assert.is_nil(err)
      eq(true, result)
      eq('/my/repo', captured_repo)
      eq('libs/foo', captured_path)
      eq('https://github.com/example/repo.git', captured_url)
    end)

    it('should invalidate cache after success', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:set_url('https://example.com/repo.git')
      assert.is_nil(sub._info)
    end)

    it('should propagate error', function()
      git_submodule.set_url = function()
        return nil, { 'set_url failed' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:set_url('https://example.com/repo.git')

      assert.is_nil(result)
      eq({ 'set_url failed' }, err)
    end)

    it('should not invalidate cache when url is nil', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:set_url(nil)
      assert.is_not_nil(sub._info)
    end)
  end)

  describe('is_initialized()', function()
    it('should return true for initialized status', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')

      assert.is_true(sub:is_initialized())
    end)

    it('should return true for modified status', function()
      local sub = GitSubmodule(make_repo(), 'libs/baz')

      assert.is_true(sub:is_initialized())
    end)

    it('should return true for conflicts status', function()
      local sub = GitSubmodule(make_repo(), 'libs/qux')

      assert.is_true(sub:is_initialized())
    end)

    it('should return false for uninitialized status', function()
      local sub = GitSubmodule(make_repo(), 'libs/bar')

      assert.is_false(sub:is_initialized())
    end)

    it('should return false on error', function()
      git_submodule.list = function()
        return nil, { 'error' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')

      assert.is_false(sub:is_initialized())
    end)
  end)

  describe('is_modified()', function()
    it('should return true for modified status', function()
      local sub = GitSubmodule(make_repo(), 'libs/baz')

      assert.is_true(sub:is_modified())
    end)

    it('should return false for initialized status', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')

      assert.is_false(sub:is_modified())
    end)

    it('should return false for uninitialized status', function()
      local sub = GitSubmodule(make_repo(), 'libs/bar')

      assert.is_false(sub:is_modified())
    end)

    it('should return false for conflicts status', function()
      local sub = GitSubmodule(make_repo(), 'libs/qux')

      assert.is_false(sub:is_modified())
    end)

    it('should return false on error', function()
      git_submodule.list = function()
        return nil, { 'error' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')

      assert.is_false(sub:is_modified())
    end)
  end)

  describe('has_conflicts()', function()
    it('should return true for conflicts status', function()
      local sub = GitSubmodule(make_repo(), 'libs/qux')

      assert.is_true(sub:has_conflicts())
    end)

    it('should return false for initialized status', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')

      assert.is_false(sub:has_conflicts())
    end)

    it('should return false for uninitialized status', function()
      local sub = GitSubmodule(make_repo(), 'libs/bar')

      assert.is_false(sub:has_conflicts())
    end)

    it('should return false for modified status', function()
      local sub = GitSubmodule(make_repo(), 'libs/baz')

      assert.is_false(sub:has_conflicts())
    end)

    it('should return false on error', function()
      git_submodule.list = function()
        return nil, { 'error' }
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')

      assert.is_false(sub:has_conflicts())
    end)
  end)

  describe('reset_cache()', function()
    it('should clear _info', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      assert.is_not_nil(sub._info)

      sub:reset_cache()
      assert.is_nil(sub._info)
    end)

    it('should allow refetch after reset', function()
      local call_count = 0
      git_submodule.list = function()
        call_count = call_count + 1
        return vim.deepcopy(mock_submodules), nil
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub:info()
      eq(1, call_count)

      sub:reset_cache()
      sub:info()
      eq(2, call_count)
    end)

    it('should pick up changed data after reset', function()
      local current_status = 'initialized'
      git_submodule.list = function()
        return {
          { path = 'libs/foo', hash = 'abc123', ref = 'v1.0', status = current_status },
        }, nil
      end

      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local info1 = sub:info()
      eq('initialized', info1.status)

      current_status = 'modified'
      sub:reset_cache()
      local info2 = sub:info()
      eq('modified', info2.status)
    end)
  end)
end)
