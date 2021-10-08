local utils = require('vgit.core.utils')

local it = it
local describe = describe
local eq = assert.are.same
local not_eq = assert.are_not.same

describe('utils:', function()
  describe('retrieve', function()
    it('should invoke a function if passed in', function()
      local test_fn = function(value)
        return value
      end
      eq(utils.retrieve(test_fn, 42), 42)
      not_eq(utils.retrieve(test_fn, 42), 22)
    end)
  end)

  describe('round', function()
    it('should round pi to 3', function()
      eq(utils.round(3.14159265359), 3)
    end)
  end)

  describe('strip_substring', function()
    it('should remove "/bar" from "foo/bar/baz"', function()
      eq(utils.strip_substring('foo/bar/baz', '/bar'), 'foo/baz')
    end)
    it('should remove "foo/baz" from "foo/bar/baz"', function()
      eq(utils.strip_substring('foo/bar/baz', '/bar'), 'foo/baz')
    end)
    it(
      'should remove "helix-core/src" from "helix-core/src/comment.rs"',
      function()
        eq(
          utils.strip_substring('helix-core/src/comment.rs', 'helix-core/src'),
          '/comment.rs'
        )
      end
    )
    it(
      'should remove "helix-core/src/" from "helix-core/src/comment.rs"',
      function()
        eq(
          utils.strip_substring('helix-core/src/comment.rs', 'helix-core/src/'),
          'comment.rs'
        )
      end
    )
    it('should remove "x-c" from "helix-core"', function()
      eq(utils.strip_substring('helix-core', 'x-c'), 'heliore')
    end)
    it('should remove "ab" from "ababababa"', function()
      eq(utils.strip_substring('ababababa', 'ab'), 'abababa')
    end)
    it('should remove "ababababa" from "abababab"', function()
      eq(utils.strip_substring('ababababa', 'abababab'), 'a')
    end)
    it('should remove "ababababa" from "ababababa"', function()
      eq(utils.strip_substring('ababababa', 'ababababa'), '')
    end)
    it('should not remove "lua/" from "vgit.lua"', function()
      eq(utils.strip_substring('vgit.lua', 'lua/'), 'vgit.lua')
    end)
  end)

  describe('object_assign', function()
    it(
      'should assign attributes in b into a regardless of if a has any of the attributes',
      function()
        local a = {}
        local b = {
          config = {
            line_number = {
              enabled = false,
              width = 10,
            },
          },
        }
        local c = utils.object_assign(a, b)
        eq(c, b)
      end
    )
    it('should handle nested object assignment', function()
      local a = {
        config = {
          line_number = {
            width = 20,
          },
        },
      }
      local b = {
        config = {
          line_number = {
            enabled = false,
            width = 10,
          },
        },
      }
      local c = utils.object_assign(a, b)
      eq(c, b)
    end)
  end)
end)
