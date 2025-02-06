local utils = require('vgit.core.utils')

local eq = assert.are.same

describe('utils.str:', function()
  describe('str.split', function()
    it('should split a string by the given delimiter', function()
      local s = 'a,b,c'
      local result = utils.str.split(s, ',')
      eq(result, { 'a', 'b', 'c' })
    end)
  end)

  describe('str.length', function()
    it('should return the length of a string', function()
      local s = 'hello'
      local length = utils.str.length(s)
      eq(length, 5)
    end)

    it('should return the correct length for a string with multibyte characters', function()
      local s = 'こんにちは'
      local length = utils.str.length(s)
      eq(length, 5)
    end)
  end)

  describe('str.shorten', function()
    it('should shorten a string to the given limit and add "..." if it exceeds the limit', function()
      local s = 'hello world'
      local shortened = utils.str.shorten(s, 8)
      eq(shortened, 'hello...')
    end)

    it('should not modify the string if it does not exceed the limit', function()
      local s = 'hello'
      local shortened = utils.str.shorten(s, 10)
      eq(shortened, s)
    end)
  end)

  describe('str.concat', function()
    it('should concatenate two strings and return the concatenated string and range', function()
      local existing_text = 'hello'
      local new_text = ' world'
      local concatenated, range = utils.str.concat(existing_text, new_text)
      eq(concatenated, 'hello world')
      eq(range, { top = 5, bot = 11 })
    end)
  end)
  describe('strip', function()
    it('should remove "/bar" from "foo/bar/baz"', function()
      eq(utils.str.strip('foo/bar/baz', '/bar'), 'foo/baz')
    end)

    it('should remove "foo/baz" from "foo/bar/baz"', function()
      eq(utils.str.strip('foo/bar/baz', '/bar'), 'foo/baz')
    end)

    it('should remove "helix-core/src" from "helix-core/src/comment.rs"', function()
      eq(utils.str.strip('helix-core/src/comment.rs', 'helix-core/src'), '/comment.rs')
    end)

    it('should remove "helix-core/src/" from "helix-core/src/comment.rs"', function()
      eq(utils.str.strip('helix-core/src/comment.rs', 'helix-core/src/'), 'comment.rs')
    end)

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
end)
