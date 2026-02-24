local eq = assert.are.same

local mock_event = {
  await = function() end,
  async = function(fn)
    return fn
  end,
  debounce_async = function(fn)
    return fn, function() end
  end,
  on = function() end,
  emit = function() end,
  custom_on = function()
    return function() end
  end,
  buffer_on = function() end,
  promisify = function(fn)
    return fn
  end,
  group = 'VGitGroup',
  register_module = function() end,
}

package.loaded['vgit.core.event'] = mock_event

describe('stash_command:', function()
  local original_packages = {}

  local function save_package(name)
    original_packages[name] = package.loaded[name]
  end

  local function restore_packages()
    for name, mod in pairs(original_packages) do
      package.loaded[name] = mod
    end
    original_packages = {}
  end

  local function make_mock_repo()
    return {
      get_path = function()
        return '/tmp/repo'
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
          return make_mock_repo(), nil
        end,
      }

    save_package('vgit.git.git_stash')
    package.loaded['vgit.git.git_stash'] = overrides.git_stash
      or {
        add = function()
          return {}, nil
        end,
        apply = function()
          return {}, nil
        end,
        pop = function()
          return {}, nil
        end,
        drop = function()
          return {}, nil
        end,
        clear = function()
          return {}, nil
        end,
        list = function()
          return {}, nil
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
        git_stash = {
          list = function()
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

    it('"add" → calls git_stash.add', function()
      local add_called = false
      setup_defaults({
        git_stash = {
          add = function()
            add_called = true
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'add' })
      assert.is_true(add_called)
    end)

    it('"pop" (no index) → calls git_stash.pop with stash@{0}', function()
      local pop_ref = nil
      setup_defaults({
        git_stash = {
          pop = function(_, ref)
            pop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'pop' })
      eq('stash@{0}', pop_ref)
    end)

    it('"pop 2" → calls git_stash.pop with stash@{2}', function()
      local pop_ref = nil
      setup_defaults({
        git_stash = {
          pop = function(_, ref)
            pop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'pop', '2' })
      eq('stash@{2}', pop_ref)
    end)

    it('"apply" (no index) → calls git_stash.apply with stash@{0}', function()
      local apply_ref = nil
      setup_defaults({
        git_stash = {
          apply = function(_, ref)
            apply_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'apply' })
      eq('stash@{0}', apply_ref)
    end)

    it('"apply 3" → calls git_stash.apply with stash@{3}', function()
      local apply_ref = nil
      setup_defaults({
        git_stash = {
          apply = function(_, ref)
            apply_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'apply', '3' })
      eq('stash@{3}', apply_ref)
    end)

    it('"drop" (no index) → calls git_stash.drop with stash@{0}', function()
      local drop_ref = nil
      setup_defaults({
        git_stash = {
          drop = function(_, ref)
            drop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'drop' })
      eq('stash@{0}', drop_ref)
    end)

    it('"drop 1" → calls git_stash.drop with stash@{1}', function()
      local drop_ref = nil
      setup_defaults({
        git_stash = {
          drop = function(_, ref)
            drop_ref = ref
            return {}, nil
          end,
        },
      })
      load_cmd().execute({ 'drop', '1' })
      eq('stash@{1}', drop_ref)
    end)

    it('"clear" → calls git_stash.clear', function()
      local clear_called = false
      setup_defaults({
        git_stash = {
          clear = function()
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
        git_stash = {
          list = function()
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
        git_stash = {
          list = function()
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
        git_stash = {
          list = function()
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

    it('should show error when git_stash.add fails', function()
      local error_msg = nil
      setup_defaults({
        git_stash = {
          add = function()
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

    it('should show error when git_stash.pop fails', function()
      local error_msg = nil
      setup_defaults({
        git_stash = {
          pop = function()
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

    it('should show error when git_stash.apply fails', function()
      local error_msg = nil
      setup_defaults({
        git_stash = {
          apply = function()
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

    it('should show error when git_stash.drop fails', function()
      local error_msg = nil
      setup_defaults({
        git_stash = {
          drop = function()
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

    it('should show error when git_stash.clear fails', function()
      local error_msg = nil
      setup_defaults({
        git_stash = {
          clear = function()
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
end)
