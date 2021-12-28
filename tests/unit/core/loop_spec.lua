local loop = require('vgit.core.loop')
local mock = require('luassert.mock')

local describe = describe
local it = it
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

describe('loop:', function()
  describe('watch', function()
    before_each(function()
      vim.loop = mock(vim.loop, true)
      vim.loop.new_fs_event.returns({ foo = 'bar' })
    end)
    after_each(function()
      mock.revert(vim.loop)
    end)
    it('should unwatch an event by calling vim loop', function()
      local callback = function() end
      loop.watch('/foo/bar/baz', callback)
      assert.stub(vim.loop.fs_event_start).was_called_with(
        { foo = 'bar' },
        '/foo/bar/baz',
        {

          watch_entry = false,
          stat = false,
          recursive = false,
        },
        callback
      )
    end)
  end)

  describe('unwatch', function()
    before_each(function()
      vim.loop = mock(vim.loop, true)
    end)
    after_each(function()
      mock.revert(vim.loop)
    end)
    it('should create an fs event that watches a file', function()
      loop.unwatch({ foo = 'bar' })
      assert.stub(vim.loop.fs_event_stop).was_called_with({ foo = 'bar' })
    end)
  end)
end)
