local eq = assert.are.same
local mock_event = require('tests.helpers.mock_event').install()

describe('worktree_command:', function()
  local save_package, restore_packages = require('tests.helpers.package_mock').create()

  local function make_mock_repo(overrides)
    overrides = overrides or {}
    return {
      get_path = function()
        return '/tmp/repo'
      end,
      worktree_add = overrides.worktree_add or function()
        return {}, nil
      end,
      worktree_remove = overrides.worktree_remove or function()
        return {}, nil
      end,
      worktree_list = overrides.worktree_list or function()
        return {}, nil
      end,
    }
  end

  local function setup_defaults(overrides)
    overrides = overrides or {}

    save_package('vgit.git.repository')
    package.loaded['vgit.git.repository'] = overrides.repository
      or {
        current = function()
          return make_mock_repo(overrides.repo_methods), nil
        end,
      }

    save_package('vgit.ui.display_service')
    package.loaded['vgit.ui.display_service'] = overrides.display_service
      or {
        show_worktree = function() end,
      }

    save_package('vgit.core.console')
    package.loaded['vgit.core.console'] = overrides.console
      or {
        error = function() end,
        info = function() end,
      }
  end

  after_each(function()
    restore_packages()
    package.loaded['vgit.core.event'] = mock_event
    package.loaded['vgit.cli.commands.worktree'] = nil
  end)

  local function load_cmd()
    package.loaded['vgit.cli.commands.worktree'] = nil
    return require('vgit.cli.commands.worktree')
  end

  describe('parse_args (via execute)', function()
    it('no args → shows worktree screen', function()
      local show_data = nil
      local worktrees = { { path = '/tmp/wt', head = 'abc', branch = 'feat' } }
      setup_defaults({
        repo_methods = {
          worktree_list = function()
            return worktrees, nil
          end,
        },
        display_service = {
          show_worktree = function(data)
            show_data = data
          end,
        },
      })
      load_cmd().execute({})
      assert.is_not_nil(show_data)
      eq(worktrees, show_data.worktrees)
    end)

    it('"add <path>" → calls worktree_add', function()
      local add_path = nil
      setup_defaults({
        repo_methods = {
          worktree_add = function(_, path)
            add_path = path
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'add', '/tmp/new-wt' })
      eq('/tmp/new-wt', add_path)
    end)

    it('"add <path> <branch>" → passes branch option', function()
      local add_path, add_opts
      setup_defaults({
        repo_methods = {
          worktree_add = function(_, path, opts)
            add_path = path
            add_opts = opts
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'add', '/tmp/new-wt', 'develop' })
      eq('/tmp/new-wt', add_path)
      eq({ branch = 'develop' }, add_opts)
    end)

    it('"remove <path>" → calls worktree_remove', function()
      local remove_path = nil
      setup_defaults({
        repo_methods = {
          worktree_remove = function(_, path)
            remove_path = path
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'remove', '/tmp/old-wt' })
      eq('/tmp/old-wt', remove_path)
    end)
  end)

  describe('error handling', function()
    it('should show error when repo is not found', function()
      local error_msg = nil
      setup_defaults({
        repository = {
          current = function()
            return nil, 'not a git repository'
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({})
      eq('not a git repository', error_msg)
    end)

    it('should show error when add has no path', function()
      local error_msg = nil
      setup_defaults({
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'add' })
      eq('Path is required: VGit worktree add <path> [branch]', error_msg)
    end)

    it('should show error when remove has no path', function()
      local error_msg = nil
      setup_defaults({
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'remove' })
      eq('Path is required: VGit worktree remove <path>', error_msg)
    end)

    it('should show error when switch has no path', function()
      local error_msg = nil
      setup_defaults({
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'switch' })
      eq('Path is required: VGit worktree switch <path>', error_msg)
    end)

    it('should show error when worktree_add fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          worktree_add = function()
            return nil, { 'fatal: path already exists' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'add', '/tmp/wt' })
      eq('fatal: path already exists', error_msg)
    end)

    it('should show error when worktree_remove fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          worktree_remove = function()
            return nil, { 'fatal: not a valid worktree' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'remove', '/tmp/wt' })
      eq('fatal: not a valid worktree', error_msg)
    end)

    it('should show error when worktree_list fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          worktree_list = function()
            return nil, { 'failed to list' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({})
      eq('failed to list', error_msg)
    end)

    it('should show info when no worktrees found', function()
      local info_msg = nil
      setup_defaults({
        repo_methods = {
          worktree_list = function()
            return {}, nil
          end,
        },
        console = {
          error = function() end,
          info = function(msg)
            info_msg = msg
          end,
        },
      })
      load_cmd().execute({})
      eq('No worktrees found', info_msg)
    end)
  end)

  describe('success messages', function()
    it('should show info on successful add', function()
      local info_msg = nil
      setup_defaults({
        repo_methods = {
          worktree_add = function()
            return {}, nil
          end,
        },
        console = {
          error = function() end,
          info = function(msg)
            info_msg = msg
          end,
        },
      })
      load_cmd().execute({ 'add', '/tmp/new-wt' })
      eq('Worktree created: /tmp/new-wt', info_msg)
    end)

    it('should show info on successful remove', function()
      local info_msg = nil
      setup_defaults({
        repo_methods = {
          worktree_remove = function()
            return {}, nil
          end,
        },
        console = {
          error = function() end,
          info = function(msg)
            info_msg = msg
          end,
        },
      })
      load_cmd().execute({ 'remove', '/tmp/old-wt' })
      eq('Worktree removed: /tmp/old-wt', info_msg)
    end)
  end)
end)
