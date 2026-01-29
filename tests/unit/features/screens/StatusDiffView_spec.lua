local describe = require('plenary.busted').describe
local it = require('plenary.busted').it
local assert = require('luassert')

describe('StatusDiffView', function()
  local StatusDiffView, repository, console

  before_each(function()
    StatusDiffView = require('vgit.features.screens.StatusDiffView')
    repository = require('vgit.git.repository')
    console = require('vgit.core.console')
  end)

  describe('create()', function()
    it('should reject when data is nil', function()
      local view = StatusDiffView()
      local result = view:create(nil)
      assert.is_false(result)
    end)

    it('should reject when data has no entries', function()
      local view = StatusDiffView()
      local result = view:create({})
      assert.is_false(result)
    end)

    it('should reject when entries is empty table', function()
      local view = StatusDiffView()
      local result = view:create({ entries = {} })
      assert.is_false(result)
    end)

    it('should accept when data has entries', function()
      local view = StatusDiffView()
      local result = view:create({
        entries = {
          {
            title = 'Modified Files',
            entries = {
              {
                type = 'unstaged',
                status = {
                  filename = 'test.lua',
                  staged = false,
                  unstaged = true,
                },
              },
            },
          },
        },
      })
      assert.is_true(result)
    end)
  end)

  describe('_validate_entries_data()', function()
    it('should return false when entries is missing', function()
      local view = StatusDiffView()
      local result = view:_validate_entries_data({})
      assert.is_false(result)
    end)

    it('should return false when entries is not a table', function()
      local view = StatusDiffView()
      local result = view:_validate_entries_data({ entries = 'not_a_table' })
      assert.is_false(result)
    end)

    it('should return false when entries is empty', function()
      local view = StatusDiffView()
      local result = view:_validate_entries_data({ entries = {} })
      assert.is_false(result)
    end)

    it('should return true when entries has content', function()
      local view = StatusDiffView()
      local result = view:_validate_entries_data({
        entries = {
          {
            title = 'Modified Files',
            entries = { { status = { filename = 'test.lua' } } },
          },
        },
      })
      assert.is_true(result)
    end)
  end)
end)
