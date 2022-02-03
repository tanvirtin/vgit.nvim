local mock = require('luassert.mock')
local utils = require('vgit.core.utils')

local it = it
local describe = describe
local before_each = before_each
local after_each = after_each
local eq = assert.are.same
local not_eq = assert.are_not.same

describe('utils:', function()
  describe('age', function()
    before_each(function()
      os.time = mock(os.time, true)
    end)
    after_each(function()
      mock.revert(os.time)
    end)

    it('should handle a single second', function()
      local current_time = 1609477202
      local blame_time = 1609477201
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 1)
      eq(age.how_long, 'second')
      eq(age.display, '1 second ago')
    end)

    it('should handle seconds', function()
      local current_time = 1609477205
      local blame_time = 1609477200
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 5)
      eq(age.how_long, 'seconds')
      eq(age.display, '5 seconds ago')
    end)

    it('should handle a single minute', function()
      local current_time = 1609477320
      local blame_time = 1609477260
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 1)
      eq(age.how_long, 'minute')
      eq(age.display, '1 minute ago')
    end)

    it('should handle minutes', function()
      local current_time = 1609477500
      local blame_time = 1609477200
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 5)
      eq(age.how_long, 'minutes')
      eq(age.display, '5 minutes ago')
    end)

    it('should handle a single hour', function()
      local current_time = 1609484400
      local blame_time = 1609480800
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 1)
      eq(age.how_long, 'hour')
      eq(age.display, '1 hour ago')
    end)

    it('should handle hours', function()
      local current_time = 1609495200
      local blame_time = 1609477200
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 5)
      eq(age.how_long, 'hours')
      eq(age.display, '5 hours ago')
    end)

    it('should handle days', function()
      local current_time = 1609822800
      local blame_time = 1609477200
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 4)
      eq(age.how_long, 'days')
      eq(age.display, '4 days ago')
    end)

    it('should handle a single month', function()
      local current_time = 1612155600
      local blame_time = 1609477200
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 1)
      eq(age.how_long, 'month')
      eq(age.display, '1 month ago')
    end)

    it('should handle months', function()
      local current_time = 1619841600
      local blame_time = 1609477200
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 4)
      eq(age.how_long, 'months')
      eq(age.display, '4 months ago')
    end)

    it('should handle a single year', function()
      local current_time = 1641020885
      local blame_time = 1609484885
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 1)
      eq(age.how_long, 'year')
      eq(age.display, '1 year ago')
    end)

    it('should handle years', function()
      local current_time = 1609477200
      local blame_time = 1451624400
      os.time.returns(current_time)
      local age = utils.time.age(blame_time)
      eq(age.unit, 5)
      eq(age.how_long, 'years')
      eq(age.display, '5 years ago')
    end)
  end)

  describe('round', function()
    it('should round pi to 3', function()
      eq(utils.math.round(3.14159265359), 3)
    end)
  end)

  describe('strip_substring', function()
    it('should remove "/bar" from "foo/bar/baz"', function()
      eq(utils.str.strip('foo/bar/baz', '/bar'), 'foo/baz')
    end)
    it('should remove "foo/baz" from "foo/bar/baz"', function()
      eq(utils.str.strip('foo/bar/baz', '/bar'), 'foo/baz')
    end)
    it(
      'should remove "helix-core/src" from "helix-core/src/comment.rs"',
      function()
        eq(
          utils.str.strip('helix-core/src/comment.rs', 'helix-core/src'),
          '/comment.rs'
        )
      end
    )
    it(
      'should remove "helix-core/src/" from "helix-core/src/comment.rs"',
      function()
        eq(
          utils.str.strip('helix-core/src/comment.rs', 'helix-core/src/'),
          'comment.rs'
        )
      end
    )
    it('should remove "x-c" from "helix-core"', function()
      eq(utils.str.strip('helix-core', 'x-c'), 'heliore')
    end)
    it('should remove "ab" from "ababababa"', function()
      eq(utils.str.strip('ababababa', 'ab'), 'abababa')
    end)
    it('should remove "ababababa" from "abababab"', function()
      eq(utils.str.strip('ababababa', 'abababab'), 'a')
    end)
    it('should remove "ababababa" from "ababababa"', function()
      eq(utils.str.strip('ababababa', 'ababababa'), '')
    end)
    it('should not remove "lua/" from "vgit.lua"', function()
      eq(utils.str.strip('vgit.lua', 'lua/'), 'vgit.lua')
    end)
  end)

  describe('object.assign', function()
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
        local c = utils.object.assign(a, b)
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
      local c = utils.object.assign(a, b)
      eq(c, b)
    end)
  end)
end)
