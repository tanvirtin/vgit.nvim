local Object = require('vgit.core.Object')

local eq = assert.are.same

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
      eq(test.x, 3)
      eq(test.y, 4)
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
      eq(test.x, 3)
      eq(test.y, 4)
    end)
  end)

  describe('readonly', function()
    local Buffer

    before_each(function()
      Buffer = Object:extend()
      function Buffer:constructor(id)
        return {
          ['$id'] = id,
          name = 'Default',
        }
      end
    end)

    it('should allow reading a readonly property', function()
      local b = Buffer(42)
      eq(b.id, 42)
    end)

    it('should throw an error when attempting to overwrite a readonly property', function()
      local b = Buffer(42)
      assert.has_error(function()
        b.id = 99
      end, "Property 'id' is read-only.")
      eq(b.id, 42)
    end)

    it('should allow modifying normal (non-readonly) properties', function()
      local b = Buffer(42)
      b.name = 'Custom'
      eq(b.name, 'Custom')
    end)

    it('should handle multiple instances independently', function()
      local b1 = Buffer(1)
      local b2 = Buffer(2)
      eq(b1.id, 1)
      eq(b2.id, 2)
      assert.has_error(function()
        b1.id = 10
      end)
      eq(b1.id, 1)
    end)
  end)

  describe('inheritance with logic', function()
    it('should inherit the readonly logic in deep subclasses', function()
      local Parent = Object:extend()
      local Child = Parent:extend()
      function Child:constructor(val)
        return { ['$secret'] = val }
      end

      local c = Child('shh')
      eq(c.secret, 'shh')
      assert.has_error(function()
        c.secret = 'leak'
      end)
    end)
  end)
end)
