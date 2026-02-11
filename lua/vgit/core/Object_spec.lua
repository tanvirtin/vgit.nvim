local Object = require('vgit.core.Object')

describe('Object:', function()
  describe('is', function()
    it('should return true if a child object instance is of type parent object', function()
      local Animal = Object:extend()
      local Bird = Animal:extend()

      local bird = Bird()
      local animal = Animal()

      assert(bird:is(Animal))
      assert(bird:is(Object))
      assert(animal:is(Animal))
      assert(animal:is(Object))
    end)
  end)

  describe('extend', function()
    it('should extend an existing table', function()
      local Animal = Object:extend()
      local Bird = Animal:extend()

      local bird = Bird()
      local animal = Animal()

      assert(getmetatable(bird) == Bird)
      assert(getmetatable(animal) == Animal)
    end)

    it('should extend an existing table without it\'s properties', function()
      local Animal = Object:extend()

      function Animal:constructor()
        return {
          has_limbs = true,
        }
      end

      local Bird = Animal:extend()

      function Bird:constructor()
        return {
          has_wings = true,
        }
      end

      local bird = Bird()

      assert(bird.has_limbs ~= true)
      assert(bird.has_wings)
    end)
  end)

  describe('__call', function()
    it('returns a table of newly extended type when constructor does not return a table', function()
      local TestObject = Object:extend()

      function TestObject:constructor()
        self.x = 3
        self.y = 4
      end

      local test = TestObject()

      assert(getmetatable(test) == TestObject)
      assert.are.same(test.x, 3)
      assert.are.same(test.y, 4)
    end)

    it('returns a table of newly extended type when constructor returns a table', function()
      local TestObject = Object:extend()

      function TestObject:constructor()
        return {
          x = 3,
          y = 4,
        }
      end

      local test = TestObject()

      assert(getmetatable(test) == TestObject)
      assert.are.same(test.x, 3)
      assert.are.same(test.y, 4)
    end)
  end)
end)
