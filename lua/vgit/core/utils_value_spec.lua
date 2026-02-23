local value = require('vgit.core.utils.value')

local eq = assert.are.same

describe('value:', function()
  describe('is_nil', function()
    it('should return true for nil', function()
      eq(value.is_nil(nil), true)
    end)

    it('should return false for string', function()
      eq(value.is_nil('hello'), false)
    end)

    it('should return false for number', function()
      eq(value.is_nil(0), false)
      eq(value.is_nil(123), false)
    end)

    it('should return false for boolean false', function()
      eq(value.is_nil(false), false)
    end)

    it('should return false for empty table', function()
      eq(value.is_nil({}), false)
    end)

    it('should return false for function', function()
      eq(value.is_nil(function() end), false)
    end)
  end)

  describe('default', function()
    it('should return value when not nil', function()
      eq(value.default('hello', 'fallback'), 'hello')
      eq(value.default(42, 0), 42)
      eq(value.default(false, true), false)
      eq(value.default({}, { 'fallback' }), {})
    end)

    it('should return fallback when value is nil', function()
      eq(value.default(nil, 'fallback'), 'fallback')
      eq(value.default(nil, 0), 0)
      eq(value.default(nil, false), false)
      eq(value.default(nil, { 'fallback' }), { 'fallback' })
    end)

    it('should work with different fallback types', function()
      eq(value.default(nil, 'string_fallback'), 'string_fallback')
      eq(value.default(nil, 123), 123)
      eq(value.default(nil, { 'table' }), { 'table' })
    end)

    it('should not modify the original value', function()
      local original = 'original'
      local result = value.default(original, 'fallback')
      eq(original, 'original')
      eq(result, 'original')
    end)
  end)
end)
