local eq = assert.are.same
local mock_event = require('tests.helpers.mock_event').install()

describe('log_command:', function()
  local save_package, restore_packages = require('tests.helpers.package_mock').create()

  local function make_mock_repo(overrides)
    overrides = overrides or {}
    return {
      get_path = overrides.get_path or function()
        return '/tmp/test-repo'
      end,
      history = overrides.history or function()
        return {
          commits = function()
            return {}, nil
          end,
        }
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
    package.loaded['vgit.ui.display_service'] = overrides.display_service or {
      show_log = function() end,
    }

    save_package('vgit.core.console')
    package.loaded['vgit.core.console'] = overrides.console
      or {
        error = function() end,
        info = function() end,
      }
  end

  local function load_cmd()
    package.loaded['vgit.cli.commands.log'] = nil
    return require('vgit.cli.commands.log')
  end

  after_each(function()
    restore_packages()
    package.loaded['vgit.core.event'] = mock_event
    package.loaded['vgit.cli.commands.log'] = nil
  end)

  it('should show error when repo is not found', function()
    local last_error = nil

    setup_defaults({
      repository = {
        current = function()
          return nil, 'Not a git repository'
        end,
      },
      console = {
        error = function(msg)
          last_error = msg
        end,
        info = function() end,
      },
    })

    local log_command = load_cmd()
    log_command.execute()

    eq('Not a git repository', last_error)
  end)

  it('should show error when commits fail to load', function()
    local last_error = nil

    setup_defaults({
      repo_methods = {
        history = function()
          return {
            commits = function()
              return nil, 'Failed to read log'
            end,
          }
        end,
      },
      console = {
        error = function(msg)
          last_error = msg
        end,
        info = function() end,
      },
    })

    local log_command = load_cmd()
    log_command.execute()

    eq('Failed to read log', last_error)
  end)

  it('should show info when no commits found', function()
    local last_info = nil

    setup_defaults({
      repo_methods = {
        history = function()
          return {
            commits = function()
              return {}, nil
            end,
          }
        end,
      },
      console = {
        error = function() end,
        info = function(msg)
          last_info = msg
        end,
      },
    })

    local log_command = load_cmd()
    log_command.execute()

    eq('No commits found', last_info)
  end)

  it('should call display_service.show_log with commits and history', function()
    local show_log_data = nil
    local fake_commits = { { hash = 'abc123' }, { hash = 'def456' } }
    local fake_history = {
      commits = function()
        return fake_commits, nil
      end,
    }

    setup_defaults({
      repo_methods = {
        history = function(_, opts)
          eq(100, opts.count)
          return fake_history
        end,
        get_path = function()
          return '/tmp/test-repo'
        end,
      },
      display_service = {
        show_log = function(data)
          show_log_data = data
        end,
      },
    })

    local log_command = load_cmd()
    log_command.execute()

    assert.is_not_nil(show_log_data)
    eq(fake_commits, show_log_data.commits)
    eq(fake_history, show_log_data.history)
    eq('/tmp/test-repo', show_log_data.repo_path)
  end)
end)
