local git_submodule = require('vgit.git.git_submodule')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

local function clone_repo(source, dest)
  vim.fn.system({ 'git', '-c', 'protocol.file.allow=always', 'clone', '-q', source, dest })
  vim.fn.system({ 'git', '-C', dest, 'config', 'protocol.file.allow', 'always' })
end

describe('git_submodule:', function()
  -- ============================================================
  -- Unit tests: parameter validation (no repo, no async needed)
  -- ============================================================
  describe('parameter validation', function()
    describe('list()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.list(nil)
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)
    end)

    describe('add()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.add(nil, 'url', 'path')
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)

      it('should error when url is nil', function()
        local result, err = git_submodule.add('/repo', nil, 'path')
        assert.is_nil(result)
        eq({ 'url is required' }, err)
      end)

      it('should error when path is nil', function()
        local result, err = git_submodule.add('/repo', 'https://example.com/repo.git', nil)
        assert.is_nil(result)
        eq({ 'path is required' }, err)
      end)
    end)

    describe('init()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.init(nil)
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)
    end)

    describe('deinit()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.deinit(nil)
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)
    end)

    describe('update()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.update(nil)
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)
    end)

    describe('sync()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.sync(nil)
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)
    end)

    describe('foreach()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.foreach(nil, 'git pull')
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)

      it('should error when command is nil', function()
        local result, err = git_submodule.foreach('/repo', nil)
        assert.is_nil(result)
        eq({ 'command is required' }, err)
      end)
    end)

    describe('set_branch()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.set_branch(nil, 'main', 'lib/sub')
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)

      it('should error when path is nil', function()
        local result, err = git_submodule.set_branch('/repo', 'main', nil)
        assert.is_nil(result)
        eq({ 'path is required' }, err)
      end)

      it('should error when neither branch nor default option is provided', function()
        local result, err = git_submodule.set_branch('/repo', nil, 'lib/sub')
        assert.is_nil(result)
        eq({ 'branch is required unless using default option' }, err)
      end)
    end)

    describe('set_url()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.set_url(nil, 'lib/sub', 'https://new.url')
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)

      it('should error when path is nil', function()
        local result, err = git_submodule.set_url('/repo', nil, 'https://new.url')
        assert.is_nil(result)
        eq({ 'path is required' }, err)
      end)

      it('should error when url is nil', function()
        local result, err = git_submodule.set_url('/repo', 'lib/sub', nil)
        assert.is_nil(result)
        eq({ 'url is required' }, err)
      end)
    end)

    describe('absorbgitdirs()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.absorbgitdirs(nil)
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)
    end)

    describe('summary()', function()
      it('should error when reponame is nil', function()
        local result, err = git_submodule.summary(nil)
        assert.is_nil(result)
        eq({ 'reponame is required' }, err)
      end)
    end)
  end)

  -- ============================================================
  -- Integration tests: real git repos with async
  -- ============================================================
  describe('integration', function()
    local repo
    local source_repo
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    before_each(function()
      local err

      -- Create a source repo to use as a submodule
      source_repo, err = test_repo.create_repo({
        initial_commit = true,
        files = { ['lib.txt'] = { 'library content' } },
      })
      assert(not err, 'Failed to create source repo: ' .. tostring(err))

      -- Create the main repo
      repo, err = test_repo.create_repo({
        initial_commit = true,
        files = { ['main.txt'] = { 'main content' } },
      })
      assert(not err, 'Failed to create main repo: ' .. tostring(err))
    end)

    after_each(function()
      if repo then test_repo.cleanup(repo) end
      if source_repo then test_repo.cleanup(source_repo) end
    end)

    -- ----------------------------------------------------------
    -- add()
    -- ----------------------------------------------------------
    describe('add()', function()
      it('should add a submodule from a local repo', function()
        local result, err = git_submodule.add(repo, source_repo, 'deps/lib')

        assert(not err, 'add() failed: ' .. vim.inspect(err))
        assert(result)

        -- The submodule directory should exist on disk
        local stat = vim.loop.fs_stat(repo .. '/deps/lib/lib.txt')
        assert(stat, 'Submodule file should exist on disk')
      end)

      it('should be visible in list after add', function()
        local _, err = git_submodule.add(repo, source_repo, 'deps/lib')
        assert(not err, 'add() failed: ' .. vim.inspect(err))

        -- Commit the submodule addition so status shows it cleanly
        vim.fn.system({ 'git', '-C', repo, 'commit', '-q', '-m', 'Add submodule' })

        local subs, list_err = git_submodule.list(repo)
        assert(not list_err, 'list() failed: ' .. vim.inspect(list_err))
        assert(subs and #subs >= 1, 'Expected at least 1 submodule in list')
        eq('deps/lib', subs[1].path)
      end)

      it('should add a submodule with force option', function()
        local result, err = git_submodule.add(repo, source_repo, 'deps/lib', { force = true })

        assert(not err, 'add() with force failed: ' .. vim.inspect(err))
        assert(result)
      end)
    end)

    -- ----------------------------------------------------------
    -- list()
    -- ----------------------------------------------------------
    describe('list()', function()
      it('should return empty list when no submodules exist', function()
        local result, err = git_submodule.list(repo)

        assert(not err, 'list() failed: ' .. vim.inspect(err))
        eq({}, result)
      end)

      it('should list an initialized submodule', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.list(repo)

        assert(not err, 'list() failed: ' .. vim.inspect(err))
        eq(1, #result)
        eq('deps/lib', result[1].path)
        assert(result[1].hash and #result[1].hash > 0, 'hash should be non-empty')
        -- After add+commit, the submodule should be initialized
        eq('initialized', result[1].status)
      end)

      it('should list multiple submodules', function()
        -- Create a second source repo
        local source_repo2, create_err = test_repo.create_repo({
          initial_commit = true,
          files = { ['util.txt'] = { 'util content' } },
        })
        assert(not create_err, 'Failed to create second source repo')

        test_repo.add_submodule(repo, source_repo, 'deps/lib')
        test_repo.add_submodule(repo, source_repo2, 'deps/util')

        local result, err = git_submodule.list(repo)

        assert(not err, 'list() failed: ' .. vim.inspect(err))
        eq(2, #result)

        -- Sort by path for deterministic comparison
        table.sort(result, function(a, b)
          return a.path < b.path
        end)
        eq('deps/lib', result[1].path)
        eq('deps/util', result[2].path)

        test_repo.cleanup(source_repo2)
      end)

      it('should detect uninitialized submodule', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        -- Clone the repo fresh so the submodule is registered but not initialized
        local clone_dir = vim.fn.tempname()
        clone_repo(repo, clone_dir)

        local result, err = git_submodule.list(clone_dir)

        assert(not err, 'list() failed: ' .. vim.inspect(err))
        eq(1, #result)
        eq('deps/lib', result[1].path)
        eq('uninitialized', result[1].status)

        -- Cleanup the clone
        vim.fn.system({ 'rm', '-rf', clone_dir })
      end)
    end)

    -- ----------------------------------------------------------
    -- init() / update()
    -- ----------------------------------------------------------
    describe('init()', function()
      it('should initialize submodules in a cloned repo', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        -- Clone fresh (submodule will be uninitialized)
        local clone_dir = vim.fn.tempname()
        clone_repo(repo, clone_dir)

        -- Before init, submodule should be uninitialized
        local subs_before, _ = git_submodule.list(clone_dir)
        eq('uninitialized', subs_before[1].status)

        -- Init the submodule
        local result, err = git_submodule.init(clone_dir, 'deps/lib')
        assert(not err, 'init() failed: ' .. vim.inspect(err))
        assert(result)

        -- After init, the submodule URL should be registered but files
        -- won't appear until update
        local stat = vim.loop.fs_stat(clone_dir .. '/deps/lib/lib.txt')
        assert(not stat, 'Files should not appear until update')

        vim.fn.system({ 'rm', '-rf', clone_dir })
      end)

      it('should accept a table of paths', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local clone_dir = vim.fn.tempname()
        clone_repo(repo, clone_dir)

        local result, err = git_submodule.init(clone_dir, { 'deps/lib' })
        assert(not err, 'init() with table paths failed: ' .. vim.inspect(err))
        assert(result)

        vim.fn.system({ 'rm', '-rf', clone_dir })
      end)
    end)

    describe('update()', function()
      it('should populate submodule files after init+update', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local clone_dir = vim.fn.tempname()
        clone_repo(repo, clone_dir)

        -- Init and update
        local _, init_err = git_submodule.init(clone_dir, 'deps/lib')
        assert(not init_err, 'init() failed: ' .. vim.inspect(init_err))

        local result, err = git_submodule.update(clone_dir, 'deps/lib')
        assert(not err, 'update() failed: ' .. vim.inspect(err))
        assert(result)

        -- The submodule file should now exist
        local stat = vim.loop.fs_stat(clone_dir .. '/deps/lib/lib.txt')
        assert(stat, 'Submodule file should exist after update')

        vim.fn.system({ 'rm', '-rf', clone_dir })
      end)

      it('should support --init option to combine init+update', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local clone_dir = vim.fn.tempname()
        clone_repo(repo, clone_dir)

        -- update with init=true should combine both steps
        local result, err = git_submodule.update(clone_dir, 'deps/lib', { init = true })
        assert(not err, 'update(init=true) failed: ' .. vim.inspect(err))
        assert(result)

        local stat = vim.loop.fs_stat(clone_dir .. '/deps/lib/lib.txt')
        assert(stat, 'Submodule file should exist after update --init')

        vim.fn.system({ 'rm', '-rf', clone_dir })
      end)

      it('should support --checkout option', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local clone_dir = vim.fn.tempname()
        clone_repo(repo, clone_dir)

        local result, err = git_submodule.update(clone_dir, 'deps/lib', { init = true, checkout = true })
        assert(not err, 'update(checkout=true) failed: ' .. vim.inspect(err))
        assert(result)

        vim.fn.system({ 'rm', '-rf', clone_dir })
      end)

      it('should accept paths as a table', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local clone_dir = vim.fn.tempname()
        clone_repo(repo, clone_dir)

        local result, err = git_submodule.update(clone_dir, { 'deps/lib' }, { init = true })
        assert(not err, 'update() with table paths failed: ' .. vim.inspect(err))
        assert(result)

        vim.fn.system({ 'rm', '-rf', clone_dir })
      end)
    end)

    -- ----------------------------------------------------------
    -- sync()
    -- ----------------------------------------------------------
    describe('sync()', function()
      it('should sync submodule URLs', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.sync(repo, 'deps/lib')

        assert(not err, 'sync() failed: ' .. vim.inspect(err))
        assert(result)
      end)

      it('should sync with recursive option', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.sync(repo, nil, { recursive = true })

        assert(not err, 'sync(recursive) failed: ' .. vim.inspect(err))
        assert(result)
      end)

      it('should accept paths as a table', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.sync(repo, { 'deps/lib' })

        assert(not err, 'sync() with table paths failed: ' .. vim.inspect(err))
        assert(result)
      end)
    end)

    -- ----------------------------------------------------------
    -- deinit() edge cases
    -- ----------------------------------------------------------
    describe('deinit() edge cases', function()
      it('should deinit without force on a clean submodule', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        -- deinit without --force succeeds on a clean submodule
        local result, err = git_submodule.deinit(repo, 'deps/lib')

        assert(not err, 'deinit() failed: ' .. vim.inspect(err))
        assert(result)

        -- Submodule content should be removed
        local stat = vim.loop.fs_stat(repo .. '/deps/lib/lib.txt')
        assert(not stat, 'Submodule content should be removed after deinit')
      end)
    end)

    -- ----------------------------------------------------------
    -- list() edge cases
    -- ----------------------------------------------------------
    describe('list() edge cases', function()
      it('should detect modified submodule with + prefix', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        -- Create a commit inside the submodule directory to make it "modified"
        vim.fn.system({
          'git',
          '-C',
          repo .. '/deps/lib',
          'commit',
          '-q',
          '--allow-empty',
          '-m',
          'sub-commit',
        })

        local result, err = git_submodule.list(repo)
        assert(not err, 'list() failed: ' .. vim.inspect(err))
        eq(1, #result)
        eq('deps/lib', result[1].path)
        eq('modified', result[1].status)
      end)
    end)

    -- ----------------------------------------------------------
    -- deinit()
    -- ----------------------------------------------------------
    describe('deinit()', function()
      it('should deinit an initialized submodule with force', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        -- deinit requires --force for initialized submodules
        local result, err = git_submodule.deinit(repo, 'deps/lib', { force = true })

        assert(not err, 'deinit(force) failed: ' .. vim.inspect(err))
        assert(result)

        -- After deinit, the submodule directory should be empty
        local stat = vim.loop.fs_stat(repo .. '/deps/lib/lib.txt')
        assert(not stat, 'Submodule content should be removed after deinit')
      end)

      it('should deinit with f alias', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.deinit(repo, 'deps/lib', { f = true })

        assert(not err, 'deinit(f) failed: ' .. vim.inspect(err))
        assert(result)
      end)

      it('should deinit all submodules with --all --force', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.deinit(repo, nil, { all = true, force = true })

        assert(not err, 'deinit(all, force) failed: ' .. vim.inspect(err))
        assert(result)
      end)
    end)

    -- ----------------------------------------------------------
    -- foreach()
    -- ----------------------------------------------------------
    describe('foreach()', function()
      it('should execute a command in each submodule', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.foreach(repo, 'echo hello')

        assert(not err, 'foreach() failed: ' .. vim.inspect(err))
        assert(result)
      end)

      it('should work with quiet option', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.foreach(repo, 'echo hello', { quiet = true })

        assert(not err, 'foreach(quiet) failed: ' .. vim.inspect(err))
        assert(result)
      end)

      it('should work with recursive option', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.foreach(repo, 'echo hello', { recursive = true })

        assert(not err, 'foreach(recursive) failed: ' .. vim.inspect(err))
        assert(result)
      end)
    end)

    -- ----------------------------------------------------------
    -- set_branch()
    -- ----------------------------------------------------------
    describe('set_branch()', function()
      it('should set a branch for a submodule', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.set_branch(repo, 'main', 'deps/lib')

        -- set-branch may fail if the git version is too old, but should not crash
        if not err then assert(result) end
      end)

      it('should reset to default branch with default option', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.set_branch(repo, nil, 'deps/lib', { default = true })

        if not err then assert(result) end
      end)
    end)

    -- ----------------------------------------------------------
    -- set_url()
    -- ----------------------------------------------------------
    describe('set_url()', function()
      it('should set the URL for a submodule', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        -- Create another source to use as new URL
        local new_source, create_err = test_repo.create_repo({
          initial_commit = true,
          files = { ['new_lib.txt'] = { 'new library' } },
        })
        assert(not create_err, 'Failed to create new source repo')

        local result, err = git_submodule.set_url(repo, 'deps/lib', new_source)

        assert(not err, 'set_url() failed: ' .. vim.inspect(err))
        assert(result)

        test_repo.cleanup(new_source)
      end)
    end)

    -- ----------------------------------------------------------
    -- absorbgitdirs()
    -- ----------------------------------------------------------
    describe('absorbgitdirs()', function()
      it('should absorb git dirs without error', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.absorbgitdirs(repo)

        assert(not err, 'absorbgitdirs() failed: ' .. vim.inspect(err))
        assert(result)
      end)
    end)

    -- ----------------------------------------------------------
    -- summary()
    -- ----------------------------------------------------------
    describe('summary()', function()
      it('should return summary for repo with submodules', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.summary(repo)

        assert(not err, 'summary() failed: ' .. vim.inspect(err))
        assert(result)
      end)

      it('should return empty result for repo without submodule changes', function()
        local result, err = git_submodule.summary(repo)

        assert(not err, 'summary() failed: ' .. vim.inspect(err))
        assert(result)
      end)

      it('should work with --cached option', function()
        test_repo.add_submodule(repo, source_repo, 'deps/lib')

        local result, err = git_submodule.summary(repo, { cached = true })

        assert(not err, 'summary(cached) failed: ' .. vim.inspect(err))
        assert(result)
      end)
    end)
  end)
end)
