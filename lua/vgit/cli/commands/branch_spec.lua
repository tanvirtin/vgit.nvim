local eq = assert.are.same

-- Mock the event module to avoid async issues in tests
local mock_event = {
  await = function() end,
  async = function(fn)
    return fn
  end,
  debounce = function(fn)
    return fn, function() end
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

describe('branch_command:', function()
  local original_packages = {}

  local function save_package(name)
    original_packages[name] = package.loaded[name]
  end

  local function restore_packages()
    for name, module in pairs(original_packages) do
      package.loaded[name] = module
    end
    original_packages = {}
  end

  after_each(function()
    restore_packages()
    package.loaded['vgit.core.event'] = mock_event
    package.loaded['vgit.cli.commands.branch'] = nil
  end)

  it('should call display_service.show_branch with sorted branches', function()
    local show_branch_data = nil

    save_package('vgit.git.repository')
    package.loaded['vgit.git.repository'] = {
      current = function()
        return {
          refs = function()
            return {
              branches = function()
                return {
                  { name = 'feature', hash = 'def456' },
                  { name = 'main', hash = 'abc123' },
                  { name = 'develop', hash = 'ghi789' },
                },
                  nil
              end,
              current_branch = function()
                return 'main', nil
              end,
            }
          end,
        },
          nil
      end,
    }

    save_package('vgit.ui.display_service')
    package.loaded['vgit.ui.display_service'] = {
      show_branch = function(data)
        show_branch_data = data
      end,
    }

    save_package('vgit.core.console')
    package.loaded['vgit.core.console'] = {
      error = function() end,
      info = function() end,
    }

    package.loaded['vgit.cli.commands.branch'] = nil
    local branch_command = require('vgit.cli.commands.branch')
    branch_command.execute()

    assert.is_not_nil(show_branch_data)
    eq('main', show_branch_data.current_branch)
    -- Current branch should be first
    eq('main', show_branch_data.branches[1].name)
    -- Rest should be alphabetical
    eq('develop', show_branch_data.branches[2].name)
    eq('feature', show_branch_data.branches[3].name)
  end)

  it('should show error when repo not found', function()
    local error_msg = nil

    save_package('vgit.git.repository')
    package.loaded['vgit.git.repository'] = {
      current = function()
        return nil, 'not a git repository'
      end,
    }

    save_package('vgit.ui.display_service')
    package.loaded['vgit.ui.display_service'] = {
      show_branch = function() end,
    }

    save_package('vgit.core.console')
    package.loaded['vgit.core.console'] = {
      error = function(msg)
        error_msg = msg
      end,
      info = function() end,
    }

    package.loaded['vgit.cli.commands.branch'] = nil
    local branch_command = require('vgit.cli.commands.branch')
    branch_command.execute()

    eq('not a git repository', error_msg)
  end)

  it('should show info when no branches found', function()
    local info_msg = nil

    save_package('vgit.git.repository')
    package.loaded['vgit.git.repository'] = {
      current = function()
        return {
          refs = function()
            return {
              branches = function()
                return {}, nil
              end,
              current_branch = function()
                return nil, nil
              end,
            }
          end,
        },
          nil
      end,
    }

    save_package('vgit.ui.display_service')
    package.loaded['vgit.ui.display_service'] = {
      show_branch = function() end,
    }

    save_package('vgit.core.console')
    package.loaded['vgit.core.console'] = {
      error = function() end,
      info = function(msg)
        info_msg = msg
      end,
    }

    package.loaded['vgit.cli.commands.branch'] = nil
    local branch_command = require('vgit.cli.commands.branch')
    branch_command.execute()

    eq('No branches found', info_msg)
  end)

  it('should show error when branches fetch fails', function()
    local error_msg = nil

    save_package('vgit.git.repository')
    package.loaded['vgit.git.repository'] = {
      current = function()
        return {
          refs = function()
            return {
              branches = function()
                return nil, 'failed to list branches'
              end,
              current_branch = function()
                return nil, nil
              end,
            }
          end,
        },
          nil
      end,
    }

    save_package('vgit.ui.display_service')
    package.loaded['vgit.ui.display_service'] = {
      show_branch = function() end,
    }

    save_package('vgit.core.console')
    package.loaded['vgit.core.console'] = {
      error = function(msg)
        error_msg = msg
      end,
      info = function() end,
    }

    package.loaded['vgit.cli.commands.branch'] = nil
    local branch_command = require('vgit.cli.commands.branch')
    branch_command.execute()

    eq('failed to list branches', error_msg)
  end)
end)
