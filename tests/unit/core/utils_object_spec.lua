local utils = require('vgit.core.utils')

local eq = assert.are.same
local object = utils.object

describe('utils.object:', function()
  describe('object.assign', function()
    it('should assign attributes in b into a regardless of if a has any of the attributes', function()
      local a = {}
      local b = {
        config = {
          line_number = {
            enabled = false,
            width = 10,
          },
        },
      }
      local c = object.assign(a, b)
      eq(c, b)
    end)

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
      local c = object.assign(a, b)
      eq(c.config.line_number.enabled, false)
      eq(c.config.line_number.width, 10)
    end)
  end)

  describe('object.is_empty', function()
    it('should return true for an empty table', function()
      eq(object.is_empty({}), true)
    end)

    it('should return false for a non-empty table', function()
      eq(object.is_empty({ key = 'value' }), false)
    end)
  end)

  describe('object.first', function()
    it('should return the first value in the table', function()
      local t = { [1] = 2, [2] = 3, [3] = 1 }
      eq(object.first(t), 2)
    end)

    it('should return nil for an empty table', function()
      eq(object.first({}), nil)
    end)
  end)

  describe('object.size', function()
    it('should return the size of the table', function()
      eq(object.size({ a = 1, b = 2, c = 3 }), 3)
    end)

    it('should return 0 for an empty table', function()
      eq(object.size({}), 0)
    end)
  end)

  describe('object.defaults', function()
    it('should assign default values', function()
      local a = { a = 1 }
      local b = { a = 2, b = 3 }
      local c = object.defaults(a, b)
      eq(c, { a = 1, b = 3 })
    end)
  end)

  describe('object.extend', function()
    it('should extend an object with properties from another object', function()
      local a = { a = 1 }
      local b = { b = 2 }
      local c = object.extend(a, b)
      eq(c, { a = 1, b = 2 })
    end)
  end)

  describe('object.merge', function()
    it('should merge multiple objects into one', function()
      local a = { a = 1 }
      local b = { b = 2 }
      local c = { c = 3 }
      local d = object.merge(a, b, c)
      eq(d, { a = 1, b = 2, c = 3 })
    end)
  end)

  describe('object.pairs', function()
    it('should return pairs of keys and values', function()
      local a = { a = 1, b = 2 }
      local result = object.pairs(a)
      eq(#result, 2)
      eq(
        utils.list.some(result, function(item)
          return item[1] == 'a' and item[2] == 1
        end),
        true
      )
      eq(
        utils.list.some(result, function(item)
          return item[1] == 'b' and item[2] == 2
        end),
        true
      )
    end)
  end)

  describe('object.keys', function()
    it('should return keys of the table', function()
      local a = { a = 1, b = 2 }
      local keys = object.keys(a)
      table.sort(keys)
      eq(keys, { 'a', 'b' })
    end)
  end)

  describe('object.values', function()
    it('should return values of the table', function()
      local a = { a = 1, b = 2 }
      local values = object.values(a)
      table.sort(values)
      eq(values, { 1, 2 })
    end)
  end)

  describe('object.clone', function()
    it('should shallowly clone an object', function()
      local a = { a = 1, b = { c = 2 } }
      local b = object.clone(a)
      eq(b, a)
      b.b.c = 3
      eq(b.b.c, a.b.c)
    end)
  end)

  describe('object.each', function()
    it('should iterate over each key-value pair in the table', function()
      local a = { a = 1, b = 2 }
      local result = {}
      object.each(a, function(value, key)
        result[key] = value
      end)
      eq(result, a)
    end)
  end)

  it('should iterate over each key-value pair in the table', function()
    local a = { a = 1, b = 2 }
    local result = {}
    object.each(a, function(value, key)
      result[key] = value
    end)
    eq(result, a)
  end)
end)
