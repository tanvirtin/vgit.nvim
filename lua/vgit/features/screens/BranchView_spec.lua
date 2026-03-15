local eq = assert.are.same
local mock_event = require('tests.helpers.mock_event').install()

describe('BranchView:', function()
  local BranchView
  local save_package, restore_packages = require('tests.helpers.package_mock').create()

  before_each(function()
    package.loaded['vgit.features.screens.BranchView'] = nil
    BranchView = require('vgit.features.screens.BranchView')
  end)

  after_each(function()
    restore_packages()
    package.loaded['vgit.core.event'] = mock_event
  end)
  describe('constructor', function()
    it('should initialize search_component as nil', function()
      local view = BranchView()
      assert.is_nil(view._search_component)
    end)

    it('should initialize destroyed as false', function()
      local view = BranchView()
      assert.is_false(view._destroyed)
    end)
  end)
  describe('_build_items', function()
    it('should convert branches to items', function()
      local view = BranchView()
      local branches = {
        { name = 'main', hash = 'abc123' },
        { name = 'feature', hash = 'def456' },
      }

      local items = view:_build_items(branches, 'main')

      eq(2, #items)
      eq('main', items[1].label)
      eq('main', items[1].value)
      eq('(current)', items[1].description)
      eq('feature', items[2].label)
      eq('feature', items[2].value)
      assert.is_nil(items[2].description)
    end)

    it('should handle empty branches list', function()
      local view = BranchView()
      local items = view:_build_items({}, 'main')
      eq(0, #items)
    end)

    it('should handle nil current_branch', function()
      local view = BranchView()
      local branches = {
        { name = 'main', hash = 'abc123' },
        { name = 'feature', hash = 'def456' },
      }

      local items = view:_build_items(branches, nil)

      eq(2, #items)
      assert.is_nil(items[1].description)
      assert.is_nil(items[2].description)
    end)

    it('should mark only current branch with (current)', function()
      local view = BranchView()
      local branches = {
        { name = 'main', hash = 'abc123' },
        { name = 'develop', hash = 'def456' },
        { name = 'feature', hash = 'ghi789' },
      }

      local items = view:_build_items(branches, 'develop')

      assert.is_nil(items[1].description)
      eq('(current)', items[2].description)
      assert.is_nil(items[3].description)
    end)

    it('should set value to branch name', function()
      local view = BranchView()
      local branches = {
        { name = 'my-branch', hash = 'abc123' },
      }

      local items = view:_build_items(branches, nil)

      eq('my-branch', items[1].value)
    end)
  end)
  describe('create', function()
    it('should return false for nil data', function()
      local view = BranchView()
      assert.is_false(view:create(nil))
    end)

    it('should return false for non-table data', function()
      local view = BranchView()
      assert.is_false(view:create('string'))
      assert.is_false(view:create(123))
      assert.is_false(view:create(true))
    end)

    it('should return false when branches is nil', function()
      local view = BranchView()
      assert.is_false(view:create({}))
    end)

    it('should return false when branches is empty', function()
      local view = BranchView()
      assert.is_false(view:create({ branches = {} }))
    end)
  end)
  describe('_on_no_match', function()
    local function setup_mocks(opts)
      opts = opts or {}

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          if opts.repo_err then return nil, opts.repo_err end
          return {
            refs = function()
              return {
                checkout_new_branch = function(_, name)
                  if opts.on_checkout then opts.on_checkout(name) end
                  if opts.checkout_err then return nil, opts.checkout_err end
                  return true, nil
                end,
              }
            end,
          },
            nil
        end,
      }

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        input = function()
          return opts.input_response or 'n'
        end,
        error = function(msg)
          if opts.on_error then opts.on_error(msg) end
        end,
        info = function(msg)
          if opts.on_info then opts.on_info(msg) end
        end,
      }

      package.loaded['vgit.features.screens.BranchView'] = nil
      BranchView = require('vgit.features.screens.BranchView')
    end

    it('should do nothing for nil query', function()
      local checkout_called = false
      setup_mocks({
        input_response = 'y',
        on_checkout = function()
          checkout_called = true
        end,
      })

      local view = BranchView()
      view:_on_no_match(nil)

      assert.is_false(checkout_called)
    end)

    it('should do nothing for empty query', function()
      local checkout_called = false
      setup_mocks({
        input_response = 'y',
        on_checkout = function()
          checkout_called = true
        end,
      })

      local view = BranchView()
      view:_on_no_match('')

      assert.is_false(checkout_called)
    end)

    it('should abort when user responds with n', function()
      local checkout_called = false
      setup_mocks({
        input_response = 'n',
        on_checkout = function()
          checkout_called = true
        end,
      })

      local view = BranchView()
      view:_on_no_match('new-branch')

      assert.is_false(checkout_called)
    end)

    it('should abort when user responds with empty string', function()
      local checkout_called = false
      setup_mocks({
        input_response = '',
        on_checkout = function()
          checkout_called = true
        end,
      })

      local view = BranchView()
      view:_on_no_match('new-branch')

      assert.is_false(checkout_called)
    end)

    it('should create and checkout branch on y response', function()
      local checkout_name = nil
      setup_mocks({
        input_response = 'y',
        on_checkout = function(name)
          checkout_name = name
        end,
      })

      local view = BranchView()
      view:_on_no_match('new-branch')

      eq('new-branch', checkout_name)
    end)

    it('should create and checkout branch on yes response', function()
      local checkout_name = nil
      setup_mocks({
        input_response = 'yes',
        on_checkout = function(name)
          checkout_name = name
        end,
      })

      local view = BranchView()
      view:_on_no_match('new-branch')

      eq('new-branch', checkout_name)
    end)

    it('should show success message after creation', function()
      local info_msg = nil
      setup_mocks({
        input_response = 'y',
        on_info = function(msg)
          info_msg = msg
        end,
      })

      local view = BranchView()
      view:_on_no_match('feature-x')

      eq('Created and switched to branch feature-x', info_msg)
    end)

    it('should show error when branch creation fails', function()
      local error_msg = nil
      setup_mocks({
        input_response = 'y',
        checkout_err = { 'fatal: branch already exists' },
        on_error = function(msg)
          error_msg = msg
        end,
      })

      local view = BranchView()
      view:_on_no_match('existing-branch')

      eq({ 'fatal: branch already exists' }, error_msg)
    end)

    it('should show error when repo not found', function()
      local error_msg = nil
      setup_mocks({
        input_response = 'y',
        repo_err = 'not a git repository',
        on_error = function(msg)
          error_msg = msg
        end,
      })

      local view = BranchView()
      view:_on_no_match('new-branch')

      eq('not a git repository', error_msg)
    end)
  end)
  describe('_on_select', function()
    it('should checkout the selected branch', function()
      local checkout_name = nil

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return {
            refs = function()
              return {
                checkout = function(_, name)
                  checkout_name = name
                  return true, nil
                end,
              }
            end,
          },
            nil
        end,
      }

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        error = function() end,
        info = function() end,
      }

      package.loaded['vgit.features.screens.BranchView'] = nil
      BranchView = require('vgit.features.screens.BranchView')

      local view = BranchView()
      view:_on_select('feature-branch')

      eq('feature-branch', checkout_name)
    end)

    it('should show error when checkout fails', function()
      local error_msg = nil

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return {
            refs = function()
              return {
                checkout = function()
                  return nil,
                    {
                      'error: Your local changes would be overwritten by checkout:',
                      '\tfile.lua',
                      'Please commit your changes or stash them.',
                    }
                end,
              }
            end,
          },
            nil
        end,
      }

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        error = function(msg)
          error_msg = msg
        end,
        info = function() end,
      }

      package.loaded['vgit.features.screens.BranchView'] = nil
      BranchView = require('vgit.features.screens.BranchView')

      local view = BranchView()
      view:_on_select('bad-branch')

      eq(3, #error_msg)
      eq('error: Your local changes would be overwritten by checkout:', error_msg[1])
    end)

    it('should show success message on checkout', function()
      local info_msg = nil

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return {
            refs = function()
              return {
                checkout = function()
                  return true, nil
                end,
              }
            end,
          },
            nil
        end,
      }

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        error = function() end,
        info = function(msg)
          info_msg = msg
        end,
      }

      package.loaded['vgit.features.screens.BranchView'] = nil
      BranchView = require('vgit.features.screens.BranchView')

      local view = BranchView()
      view:_on_select('develop')

      eq('Switched to branch develop', info_msg)
    end)

    it('should not checkout when value is nil', function()
      local checkout_called = false

      save_package('vgit.git.repository')
      package.loaded['vgit.git.repository'] = {
        current = function()
          return {
            refs = function()
              return {
                checkout = function()
                  checkout_called = true
                  return true, nil
                end,
              }
            end,
          },
            nil
        end,
      }

      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        error = function() end,
        info = function() end,
      }

      package.loaded['vgit.features.screens.BranchView'] = nil
      BranchView = require('vgit.features.screens.BranchView')

      local view = BranchView()
      view:_on_select(nil)

      assert.is_false(checkout_called)
    end)
  end)
  describe('destroy', function()
    it('should set destroyed to true', function()
      local view = BranchView()
      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should be idempotent', function()
      local view = BranchView()
      view:destroy()
      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should nil search_component on destroy', function()
      local view = BranchView()
      view._search_component = {
        close = function() end,
      }

      view:destroy()

      assert.is_nil(view._search_component)
      assert.is_true(view._destroyed)
    end)

    it('should not re-nil search_component when called twice', function()
      local view = BranchView()
      view._search_component = {
        close = function() end,
      }

      view:destroy()
      assert.is_nil(view._search_component)

      view:destroy()
      assert.is_nil(view._search_component)
      assert.is_true(view._destroyed)
    end)
  end)
end)
