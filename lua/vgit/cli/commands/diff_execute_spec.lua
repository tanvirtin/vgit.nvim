local mock_event = require('tests.helpers.mock_event').install()
local eq = assert.are.same

describe('diff_command execute:', function()
  local save_package, restore_packages = require('tests.helpers.package_mock').create()
  local temporary_file

  local function load_command()
    package.loaded['vgit.cli.commands.diff'] = nil
    return require('vgit.cli.commands.diff')
  end

  local function setup_command(repo)
    local resolved_path
    local current_calls = 0
    local diff_spec
    local shown_data

    save_package('vgit.git.repository')
    package.loaded['vgit.git.repository'] = {
      for_path = function(path)
        resolved_path = path
        return repo, nil
      end,
      current = function()
        current_calls = current_calls + 1
        return nil, { 'unexpected repository.current() call' }
      end,
    }

    save_package('vgit.core.Buffer')
    package.loaded['vgit.core.Buffer'] = setmetatable({}, {
      __call = function()
        return {
          get_name = function()
            return temporary_file
          end,
        }
      end,
    })

    save_package('vgit.core.Window')
    package.loaded['vgit.core.Window'] = setmetatable({}, {
      __call = function()
        return {
          get_lnum = function()
            return 1
          end,
        }
      end,
    })

    save_package('vgit.core.console')
    package.loaded['vgit.core.console'] = {
      error = function() end,
      info = function() end,
    }

    save_package('vgit.settings.scene')
    package.loaded['vgit.settings.scene'] = {
      get = function(_, key)
        if key == 'diff_preference' then return 'unified' end
      end,
    }

    save_package('vgit.ui.display_service')
    package.loaded['vgit.ui.display_service'] = {
      show_diff = function(data)
        shown_data = data
      end,
    }

    repo.get_path = function()
      return vim.fn.fnamemodify(temporary_file, ':h')
    end
    repo.diff = function(_, spec)
      diff_spec = spec
      return { lines = { 'old', 'new' }, hunks = {}, marks = {} }
    end

    return function(args)
      load_command().execute(args)
      return resolved_path, current_calls, diff_spec, shown_data
    end
  end

  before_each(function()
    temporary_file = vim.fn.tempname() .. '.lua'
    vim.fn.writefile({ 'changed' }, temporary_file)
  end)

  after_each(function()
    if temporary_file then vim.fn.delete(temporary_file) end
    restore_packages()
    package.loaded['vgit.core.event'] = mock_event
    package.loaded['vgit.cli.commands.diff'] = nil
  end)

  it('discovers the repository from an explicit file path', function()
    local repo = {}
    local execute = setup_command(repo)

    local resolved_path, current_calls, diff_spec, shown_data = execute({ temporary_file })

    eq(temporary_file, resolved_path)
    eq(0, current_calls)
    eq(vim.fn.fnamemodify(temporary_file, ':t'), diff_spec.filename)
    eq(repo, shown_data.repo)
  end)

  it('discovers the repository from the current buffer path', function()
    local repo = {}
    local execute = setup_command(repo)

    local resolved_path, current_calls, diff_spec, shown_data = execute({ '--buffer' })

    eq(temporary_file, resolved_path)
    eq(0, current_calls)
    eq(vim.fn.fnamemodify(temporary_file, ':t'), diff_spec.filename)
    eq(repo, shown_data.repo)
  end)
end)
