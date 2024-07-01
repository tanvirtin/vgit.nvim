local list = require('vgit.core.utils.list')

local eq = assert.are.same

describe('list:', function()
  describe('list.is_list', function()
    it('should return true for a list', function()
      local l = { 1, 2, 3 }
      local result = list.is_list(l)
      eq(result, true)
    end)

    it('should return false for a non-list', function()
      local l = { key = 'value' }
      local result = list.is_list(l)
      eq(result, false)
    end)
  end)

  describe('list.is_empty', function()
    it('should return true for an empty list', function()
      local l = {}
      local result = list.is_empty(l)
      eq(result, true)
    end)

    it('should return false for a non-empty list', function()
      local l = { 1, 2, 3 }
      local result = list.is_empty(l)
      eq(result, false)
    end)
  end)

  describe('list.join', function()
    it('should join elements of a list with a separator', function()
      local l = { 'a', 'b', 'c' }
      local result = list.join(l, ',')
      eq(result, 'a,b,c')
    end)
  end)

  describe('list.pick', function()
    it('should return the specified item from the list if found', function()
      local l = { 'apple', 'banana', 'cherry' }
      local result = list.pick(l, 'banana')
      eq(result, 'banana')
    end)

    it('should return the first item if the specified item is not found', function()
      local l = { 'apple', 'banana', 'cherry' }
      local result = list.pick(l, 'pear')
      eq(result, 'apple')
    end)
  end)

  describe('list.concat', function()
    it('should concatenate two lists', function()
      local a = { 1, 2, 3 }
      local b = { 4, 5, 6 }
      local result = list.concat(a, b)
      eq(result, { 1, 2, 3, 4, 5, 6 })
    end)
  end)

  describe('list.merge', function()
    it('should merge multiple lists into one', function()
      local t = { 1, 2 }
      local a = { 3, 4 }
      local b = { 5, 6 }
      local result = list.merge(t, a, b)
      eq(result, { 1, 2, 3, 4, 5, 6 })
    end)
  end)

  describe('list.map', function()
    it('should map a function over a list', function()
      local l = { 1, 2, 3 }
      local result = list.map(l, function(x) return x * 2 end)
      eq(result, { 2, 4, 6 })
    end)
  end)

  describe('list.filter', function()
    it('should filter a list based on a callback function', function()
      local l = { 1, 2, 3, 4, 5 }
      local result = list.filter(l, function(x) return x % 2 == 0 end)
      eq(result, { 2, 4 })
    end)
  end)

  describe('list.each', function()
    it('should iterate over each item in the list', function()
      local l = { 'a', 'b', 'c' }
      local result = {}
      list.each(l, function(item) table.insert(result, item) end)
      eq(result, { 'a', 'b', 'c' })
    end)
  end)

  describe('list.reduce', function()
    it('should reduce a list to a single value using an accumulator and callback function', function()
      local l = { 1, 2, 3, 4 }
      local result = list.reduce(l, 0, function(acc, x) return acc + x end)
      eq(result, 10)
    end)
  end)

  describe('list.find', function()
    it('should find the first item in the list that satisfies the callback function', function()
      local l = { 'apple', 'banana', 'cherry' }
      local result = list.find(l, function(item) return string.len(item) == 5 end)
      eq(result, 'apple')
    end)

    it('should return nil if no item satisfies the callback function', function()
      local l = { 'apple', 'banana', 'cherry' }
      local result = list.find(l, function(item) return item == 'pear' end)
      eq(result, nil)
    end)
  end)

  describe('list.replace', function()
    it('should replace items in a list within a specified range', function()
      local l = { 'a', 'b', 'c', 'd', 'e' }
      local result = list.replace(l, 2, 4, { 'x', 'y', 'z' })
      eq(result, { 'a', 'x', 'y', 'z', 'e' })
    end)
  end)

  describe('list.extract', function()
    it('should extract items from a list within a specified range', function()
      local l = { 'a', 'b', 'c', 'd', 'e' }
      local result = list.extract(l, 2, 4)
      eq(result, { 'b', 'c', 'd' })
    end)
  end)

  describe('list.some', function()
    it('should return true if at least one item in the list satisfies the callback function', function()
      local l = { 'apple', 'banana', 'cherry' }
      local result = list.some(l, function(item) return item == 'banana' end)
      eq(result, true)
    end)

    it('should return false if no item in the list satisfies the callback function', function()
      local l = { 'apple', 'banana', 'cherry' }
      local result = list.some(l, function(item) return item == 'pear' end)
      eq(result, false)
    end)
  end)
end)
