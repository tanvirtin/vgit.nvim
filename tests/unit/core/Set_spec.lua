local Set = require('vgit.core.Set')

describe('Set:', function()
  describe('has', function()
    it('should return true if a given key is in list', function()
      local set = Set({ 'a', 'b', 'c', 'c' })

      assert(set:has('b'))
    end)

    it('should return false if a given key is not in list', function()
      local set = Set({ 'a', 'b', 'c', 'c' })

      assert.False(set:has('z'))
    end)
  end)

  describe('add', function()
    it('should add a key to the set', function()
      local set = Set({ 'a', 'b', 'c', 'c' })

      set:add('z')

      assert(set:has('z'))
    end)

    it(
      'should replace existing key with new key if they are the same',
      function()
        local set = Set({ 'a', 'b', 'c', 'c' })

        set:add('c')

        assert(set:has('c'))
      end
    )
  end)

  describe('delete', function()
    it('should delete existing key from set', function()
      local set = Set({ 'a', 'b', 'c', 'c' })

      set:delete('c')

      assert.False(set:has('c'))
    end)

    it('should have no effect deleting a key that does not exist', function()
      local set = Set({ 'a', 'b', 'c', 'c' })

      set:delete('33')

      assert.False(set:has('33'))
    end)
  end)

  describe('to_list', function()
    it('should return back a list containing unique elements', function()
      local set = Set({ 'a', 'a', 'b', 'b', 'c', 'c', 'd' })

      local list = set:to_list()

      local count_map = {}

      for i = 1, #list do
        local value = list[i]

        if count_map[value] then
          count_map[value] = count_map[value] + 1
        else
          count_map[value] = 1
        end
      end

      local eq = assert.are.same

      eq(count_map['a'], 1)
      eq(count_map['b'], 1)
      eq(count_map['c'], 1)
      eq(count_map['d'], 1)
    end)
  end)

  describe('for_each', function()
    local set = Set({ 'a', 'a', 'b', 'b', 'c', 'c', 'd' })

    local count_map = {}
    local count = 0

    set:for_each(function(value, index)
      count = count + index
      if count_map[value] then
        count_map[value] = count_map[value] + 1
      else
        count_map[value] = 1
      end
    end)

    local eq = assert.are.same

    eq(count_map['a'], 1)
    eq(count_map['b'], 1)
    eq(count_map['c'], 1)
    eq(count_map['d'], 1)
    eq(count, 11)
  end)

  it('should allow chaining side effect commands', function()
    local set = Set({ 'a', 'a', 'b', 'b', 'c', 'c', 'd' })

    local hasZ = set:add('z'):delete('z'):has('z')

    assert.False(hasZ)
  end)
end)
