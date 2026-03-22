local eq = assert.are.same

describe('git_worktree:', function()
  local save_package, restore_packages = require('tests.helpers.package_mock').create()

  local function setup_defaults(overrides)
    overrides = overrides or {}

    save_package('vgit.git.GitQueryBuilder')
    package.loaded['vgit.git.GitQueryBuilder'] = overrides.GitQueryBuilder
  end

  after_each(function()
    restore_packages()
    package.loaded['vgit.git.git_worktree'] = nil
  end)

  local function load_module()
    package.loaded['vgit.git.git_worktree'] = nil
    return require('vgit.git.git_worktree')
  end

  local function make_query_builder(execute_fn)
    local builder = {}
    local mt = { __index = builder }

    function builder:raw_args(...)
      self._args = { ... }
      return self
    end

    function builder:execute()
      return execute_fn(self._args)
    end

    -- Must return a callable table (not a function) because lazy() calls pairs() on it
    return setmetatable({}, {
      __call = function(_, reponame)
        local instance = setmetatable({ _reponame = reponame }, mt)
        return instance
      end,
    })
  end

  describe('list', function()
    it('should return error when reponame is nil', function()
      setup_defaults({ GitQueryBuilder = make_query_builder(function()
        return {}, nil
      end) })
      local git_worktree = load_module()
      local result, err = git_worktree.list(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should return empty array for empty output', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(err)
      eq({}, result)
    end)

    it('should parse single worktree', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return {
            'worktree /home/user/project',
            'HEAD abc123def456',
            'branch refs/heads/main',
            '',
          },
            nil
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(err)
      eq(1, #result)
      eq('/home/user/project', result[1].path)
      eq('abc123def456', result[1].head)
      eq('main', result[1].branch)
    end)

    it('should parse multiple worktrees', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return {
            'worktree /home/user/project',
            'HEAD abc123',
            'branch refs/heads/main',
            '',
            'worktree /home/user/project-feature',
            'HEAD def456',
            'branch refs/heads/feature',
            '',
          },
            nil
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(err)
      eq(2, #result)
      eq('/home/user/project', result[1].path)
      eq('main', result[1].branch)
      eq('/home/user/project-feature', result[2].path)
      eq('feature', result[2].branch)
    end)

    it('should parse detached worktree', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return {
            'worktree /home/user/detached',
            'HEAD abc123',
            'detached',
            '',
          },
            nil
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(err)
      assert.is_true(result[1].detached)
    end)

    it('should parse bare worktree', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return {
            'worktree /home/user/bare',
            'HEAD abc123',
            'bare',
            '',
          },
            nil
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(err)
      assert.is_true(result[1].bare)
    end)

    it('should parse locked and prunable flags', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return {
            'worktree /home/user/locked',
            'HEAD abc123',
            'branch refs/heads/locked-branch',
            'locked',
            'prunable',
            '',
          },
            nil
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(err)
      assert.is_true(result[1].locked)
      assert.is_true(result[1].prunable)
    end)

    it('should handle worktree without trailing blank line', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return {
            'worktree /home/user/project',
            'HEAD abc123',
            'branch refs/heads/main',
          },
            nil
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(err)
      eq(1, #result)
      eq('main', result[1].branch)
    end)

    it('should propagate execute errors', function()
      setup_defaults({
        GitQueryBuilder = make_query_builder(function()
          return nil, { 'fatal: not a git repository' }
        end),
      })
      local git_worktree = load_module()
      local result, err = git_worktree.list('/tmp/repo')
      assert.is_nil(result)
      eq({ 'fatal: not a git repository' }, err)
    end)
  end)

  describe('add', function()
    it('should return error when reponame is nil', function()
      setup_defaults({ GitQueryBuilder = make_query_builder(function()
        return {}, nil
      end) })
      local git_worktree = load_module()
      local result, err = git_worktree.add(nil, '/tmp/wt')
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should return error when path is nil', function()
      setup_defaults({ GitQueryBuilder = make_query_builder(function()
        return {}, nil
      end) })
      local git_worktree = load_module()
      local result, err = git_worktree.add('/tmp/repo', nil)
      assert.is_nil(result)
      eq({ 'path is required' }, err)
    end)

    it('should pass basic args', function()
      local captured_args
      setup_defaults({
        GitQueryBuilder = make_query_builder(function(args)
          captured_args = args
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      git_worktree.add('/tmp/repo', '/tmp/wt')
      eq({ 'worktree', 'add', '/tmp/wt' }, captured_args)
    end)

    it('should pass --detach flag', function()
      local captured_args
      setup_defaults({
        GitQueryBuilder = make_query_builder(function(args)
          captured_args = args
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      git_worktree.add('/tmp/repo', '/tmp/wt', { detach = true })
      eq({ 'worktree', 'add', '--detach', '/tmp/wt' }, captured_args)
    end)

    it('should pass -b flag for new branch', function()
      local captured_args
      setup_defaults({
        GitQueryBuilder = make_query_builder(function(args)
          captured_args = args
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      git_worktree.add('/tmp/repo', '/tmp/wt', { new_branch = 'feat' })
      eq({ 'worktree', 'add', '-b', 'feat', '/tmp/wt' }, captured_args)
    end)

    it('should pass branch to checkout', function()
      local captured_args
      setup_defaults({
        GitQueryBuilder = make_query_builder(function(args)
          captured_args = args
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      git_worktree.add('/tmp/repo', '/tmp/wt', { branch = 'develop' })
      eq({ 'worktree', 'add', '/tmp/wt', 'develop' }, captured_args)
    end)
  end)

  describe('remove', function()
    it('should return error when reponame is nil', function()
      setup_defaults({ GitQueryBuilder = make_query_builder(function()
        return {}, nil
      end) })
      local git_worktree = load_module()
      local result, err = git_worktree.remove(nil, '/tmp/wt')
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should return error when path is nil', function()
      setup_defaults({ GitQueryBuilder = make_query_builder(function()
        return {}, nil
      end) })
      local git_worktree = load_module()
      local result, err = git_worktree.remove('/tmp/repo', nil)
      assert.is_nil(result)
      eq({ 'path is required' }, err)
    end)

    it('should pass basic args', function()
      local captured_args
      setup_defaults({
        GitQueryBuilder = make_query_builder(function(args)
          captured_args = args
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      git_worktree.remove('/tmp/repo', '/tmp/wt')
      eq({ 'worktree', 'remove', '/tmp/wt' }, captured_args)
    end)

    it('should pass --force flag', function()
      local captured_args
      setup_defaults({
        GitQueryBuilder = make_query_builder(function(args)
          captured_args = args
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      git_worktree.remove('/tmp/repo', '/tmp/wt', { force = true })
      eq({ 'worktree', 'remove', '--force', '/tmp/wt' }, captured_args)
    end)
  end)

  describe('prune', function()
    it('should return error when reponame is nil', function()
      setup_defaults({ GitQueryBuilder = make_query_builder(function()
        return {}, nil
      end) })
      local git_worktree = load_module()
      local result, err = git_worktree.prune(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should pass correct args', function()
      local captured_args
      setup_defaults({
        GitQueryBuilder = make_query_builder(function(args)
          captured_args = args
          return {}, nil
        end),
      })
      local git_worktree = load_module()
      git_worktree.prune('/tmp/repo')
      eq({ 'worktree', 'prune' }, captured_args)
    end)
  end)
end)
