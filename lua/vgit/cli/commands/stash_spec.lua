local eq = assert.are.same
local mock_event = require('tests.helpers.mock_event').install()

describe('stash_command:', function()
  local save_package, restore_packages = require('tests.helpers.package_mock').create()

  local function make_mock_repo(overrides)
    overrides = overrides or {}
    return {
      get_path = function()
        return '/tmp/repo'
      end,
      stash_add = overrides.stash_add or function()
        return {}, nil
      end,
      stash_pop = overrides.stash_pop or function()
        return {}, nil
      end,
      stash_apply = overrides.stash_apply or function()
        return {}, nil
      end,
      stash_drop = overrides.stash_drop or function()
        return {}, nil
      end,
      stash_clear = overrides.stash_clear or function()
        return {}, nil
      end,
      stash_list = overrides.stash_list or function()
        return {}, nil
      end,
    }
  end

  -- Set up default mocks and return overridable table; call before each test.
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
    package.loaded['vgit.ui.display_service'] = overrides.display_service or {
      show_stash = function() end,
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
    package.loaded['vgit.cli.commands.stash'] = nil
  end)

  -- Helper: load a fresh stash_command with current mocks
  local function load_cmd()
    package.loaded['vgit.cli.commands.stash'] = nil
    return require('vgit.cli.commands.stash')
  end

  describe('parse_args (via execute)', function()
    it('no args → shows stash screen', function()
      local show_stash_data = nil
      local stashes = { { context = { revision = 'stash@{0}' }, message = 'WIP' } }
      setup_defaults({
        repo_methods = {
          stash_list = function()
            return stashes, nil
          end,
        },
        display_service = {
          show_stash = function(data)
            show_stash_data = data
          end,
        },
      })
      load_cmd().execute({})
      assert.is_not_nil(show_stash_data)
      eq(stashes, show_stash_data.stashes)
    end)

    it('"add" → calls repo:stash_add', function()
      local add_called = false
      setup_defaults({
        repo_methods = {
          stash_add = function()
            add_called = true
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'add' })
      assert.is_true(add_called)
    end)

    it('"pop" (no index) → calls repo:stash_pop with stash@{0}', function()
      local pop_ref = nil
      setup_defaults({
        repo_methods = {
          stash_pop = function(_, ref)
            pop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'pop' })
      eq('stash@{0}', pop_ref)
    end)

    it('"pop 2" → calls repo:stash_pop with stash@{2}', function()
      local pop_ref = nil
      setup_defaults({
        repo_methods = {
          stash_pop = function(_, ref)
            pop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'pop', '2' })
      eq('stash@{2}', pop_ref)
    end)

    it('"apply" (no index) → calls repo:stash_apply with stash@{0}', function()
      local apply_ref = nil
      setup_defaults({
        repo_methods = {
          stash_apply = function(_, ref)
            apply_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'apply' })
      eq('stash@{0}', apply_ref)
    end)

    it('"apply 3" → calls repo:stash_apply with stash@{3}', function()
      local apply_ref = nil
      setup_defaults({
        repo_methods = {
          stash_apply = function(_, ref)
            apply_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'apply', '3' })
      eq('stash@{3}', apply_ref)
    end)

    it('"drop" (no index) → calls repo:stash_drop with stash@{0}', function()
      local drop_ref = nil
      setup_defaults({
        repo_methods = {
          stash_drop = function(_, ref)
            drop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'drop' })
      eq('stash@{0}', drop_ref)
    end)

    it('"drop 1" → calls repo:stash_drop with stash@{1}', function()
      local drop_ref = nil
      setup_defaults({
        repo_methods = {
          stash_drop = function(_, ref)
            drop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'drop', '1' })
      eq('stash@{1}', drop_ref)
    end)

    it('"clear" → calls repo:stash_clear', function()
      local clear_called = false
      setup_defaults({
        repo_methods = {
          stash_clear = function()
            clear_called = true
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'clear' })
      assert.is_true(clear_called)
    end)

    it('unknown subcommand → shows stash screen', function()
      local show_stash_data = nil
      local stashes = { { context = { revision = 'stash@{0}' }, message = 'WIP' } }
      setup_defaults({
        repo_methods = {
          stash_list = function()
            return stashes, nil
          end,
        },
        display_service = {
          show_stash = function(data)
            show_stash_data = data
          end,
        },
      })
      load_cmd().execute({ 'unknown_subcommand' })
      assert.is_not_nil(show_stash_data)
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

    it('should show info when no stashes exist', function()
      local info_msg = nil
      setup_defaults({
        repo_methods = {
          stash_list = function()
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
      eq('No stashes found', info_msg)
    end)

    it('should show error when stash list fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          stash_list = function()
            return nil, { 'failed to list stashes' }
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
      eq('failed to list stashes', error_msg)
    end)

    it('should show error when stash_add fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          stash_add = function()
            return nil, { 'nothing to stash' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'add' })
      eq('nothing to stash', error_msg)
    end)

    it('should show error when stash_pop fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          stash_pop = function()
            return nil, { 'cannot pop stash' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'pop' })
      eq('cannot pop stash', error_msg)
    end)

    it('should show error when stash_apply fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          stash_apply = function()
            return nil, { 'conflict during apply' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'apply' })
      eq('conflict during apply', error_msg)
    end)

    it('should show error when stash_drop fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          stash_drop = function()
            return nil, { 'invalid stash reference' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'drop' })
      eq('invalid stash reference', error_msg)
    end)

    it('should show error when stash_clear fails', function()
      local error_msg = nil
      setup_defaults({
        repo_methods = {
          stash_clear = function()
            return nil, { 'cannot clear stash' }
          end,
        },
        console = {
          error = function(msg)
            error_msg = msg
          end,
          info = function() end,
        },
      })
      load_cmd().execute({ 'clear' })
      eq('cannot clear stash', error_msg)
    end)
  end)

  describe('parse_args', function()
    local stash_cmd

    before_each(function()
      package.loaded['vgit.cli.commands.stash'] = nil
      stash_cmd = require('vgit.cli.commands.stash')
    end)

    it('should default to screen action with no args', function()
      local opts = stash_cmd.parse_args({})
      eq('screen', opts.action)
      assert.is_nil(opts.index)
    end)

    it('should default to screen action with nil args', function()
      local opts = stash_cmd.parse_args(nil)
      eq('screen', opts.action)
    end)

    it('should parse add action', function()
      local opts = stash_cmd.parse_args({ 'add' })
      eq('add', opts.action)
    end)

    it('should parse pop action with default index', function()
      local opts = stash_cmd.parse_args({ 'pop' })
      eq('pop', opts.action)
      eq(0, opts.index)
    end)

    it('should parse pop action with explicit index', function()
      local opts = stash_cmd.parse_args({ 'pop', '2' })
      eq('pop', opts.action)
      eq(2, opts.index)
    end)

    it('should parse apply action with index', function()
      local opts = stash_cmd.parse_args({ 'apply', '3' })
      eq('apply', opts.action)
      eq(3, opts.index)
    end)

    it('should parse drop action', function()
      local opts = stash_cmd.parse_args({ 'drop', '1' })
      eq('drop', opts.action)
      eq(1, opts.index)
    end)

    it('should parse clear action', function()
      local opts = stash_cmd.parse_args({ 'clear' })
      eq('clear', opts.action)
    end)

    it('should default to screen for unrecognized subcommand', function()
      local opts = stash_cmd.parse_args({ 'unknown' })
      eq('screen', opts.action)
    end)
  end)
end)
