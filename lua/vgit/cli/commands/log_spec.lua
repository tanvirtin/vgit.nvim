local eq = assert.are.same

-- Track calls made during tests
local last_error = nil
local last_info = nil
local show_log_data = nil

-- Stub modules before requiring log command
package.loaded['vgit.core.event'] = {
  async = function(fn)
    return function(...)
      return fn(...)
    end
  end,
  await = function() end,
}

package.loaded['vgit.core.console'] = {
  error = function(msg)
    last_error = msg
  end,
  info = function(msg)
    last_info = msg
  end,
}

local mock_repo = nil
local mock_repo_err = nil
package.loaded['vgit.git.repository'] = {
  current = function()
    return mock_repo, mock_repo_err
  end,
}

package.loaded['vgit.ui.display_service'] = {
  show_log = function(data)
    show_log_data = data
  end,
}

local log_command = require('vgit.cli.commands.log')

describe('log_command:', function()
  before_each(function()
    last_error = nil
    last_info = nil
    show_log_data = nil
    mock_repo = nil
    mock_repo_err = nil
  end)

  it('should show error when repo is not found', function()
    mock_repo_err = 'Not a git repository'

    log_command.execute()

    assert.are.equal('Not a git repository', last_error)
    assert.is_nil(show_log_data)
  end)

  it('should show error when commits fail to load', function()
    mock_repo = {
      history = function()
        return {
          commits = function()
            return nil, 'Failed to read log'
          end,
        }
      end,
    }

    log_command.execute()

    assert.are.equal('Failed to read log', last_error)
    assert.is_nil(show_log_data)
  end)

  it('should show info when no commits found', function()
    mock_repo = {
      history = function()
        return {
          commits = function()
            return {}, nil
          end,
        }
      end,
    }

    log_command.execute()

    assert.are.equal('No commits found', last_info)
    assert.is_nil(show_log_data)
  end)

  it('should call display_service.show_log with commits and history', function()
    local fake_commits = { { hash = 'abc123' }, { hash = 'def456' } }
    local fake_history = {
      commits = function()
        return fake_commits, nil
      end,
    }

    mock_repo = {
      history = function(_, opts)
        eq(100, opts.count)
        return fake_history
      end,
      get_path = function()
        return '/tmp/test-repo'
      end,
    }

    log_command.execute()

    assert.is_nil(last_error)
    assert.is_nil(last_info)
    assert.is_not_nil(show_log_data)
    eq(fake_commits, show_log_data.commits)
    eq(fake_history, show_log_data.history)
    eq('/tmp/test-repo', show_log_data.repo_path)
  end)
end)
