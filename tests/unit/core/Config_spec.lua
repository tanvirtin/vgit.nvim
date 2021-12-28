local Config = require('vgit.core.Config')

local it = it
local describe = describe
local before_each = before_each
local eq = assert.are.same

describe('Config:', function()
  local initial_state = {}

  before_each(function()
    initial_state = {
      foo = 'bar',
      bar = 'foo',
      baz = {
        foo = 'bar',
        bar = 'foo',
      },
    }
  end)

  describe('new', function()
    it('should bind the object provided into into the state object', function()
      local state = Config:new(initial_state)
      eq(state, {
        data = initial_state,
      })
    end)

    it('should throw error if invalid data type is provided', function()
      assert.has_error(function()
        Config:new(42)
      end)
    end)
  end)

  describe('size', function()
    it('should return the size of the current config', function()
      local state = Config:new(initial_state)
      eq(state:size(), 3)
      state = Config:new({})
      eq(state:size(), 0)
    end)
  end)

  describe('for_each', function()
    it('should loop over all the key value pairs', function()
      local state = Config:new(initial_state)
      local copy_state = {}
      state:for_each(function(key, value)
        copy_state[key] = value
      end)
      eq(copy_state, initial_state)
    end)
  end)

  describe('get', function()
    it('should throw error on invalid argument types', function()
      local state = Config:new({
        foo = 'bar',
      })
      assert.has_error(function()
        state:get(true)
      end)
      assert.has_error(function()
        state:get({})
      end)
      assert.has_error(function()
        state:get(1)
      end)
      assert.has_error(function()
        state:get(nil)
      end)
      assert.has_error(function()
        state:get(function() end)
      end)
    end)

    it(
      'should succesfully retrieve a value given a key from the state object',
      function()
        local state = Config:new(initial_state)
        eq(state:get('foo'), 'bar')
        eq(state:get('bar'), 'foo')
        eq(state:get('baz'), {
          foo = 'bar',
          bar = 'foo',
        })
      end
    )

    it(
      'should throw an error if a state object does not have the given key',
      function()
        local state = Config:new(initial_state)
        assert.has_error(function()
          eq(state:get('test'), nil)
        end)
      end
    )
  end)

  describe('set', function()
    it('should throw error on invalid argument types', function()
      local state = Config:new({
        foo = 'bar',
      })
      assert.has_error(function()
        state:set('foo', true)
      end)
      assert.has_error(function()
        state:set('foo', {})
      end)
      assert.has_error(function()
        state:set('foo', 1)
      end)
      assert.has_error(function()
        state:set('foo', nil)
      end)
      assert.has_error(function()
        state:set('foo', function() end)
      end)
    end)

    it('should alter an existing state attribute', function()
      local state = Config:new(initial_state)
      state:set('foo', 'a')
      state:set('bar', 'b')
      state:set('baz', {
        test1 = 1,
        test2 = 2,
      })
      eq(state:get('foo'), 'a')
      eq(state:get('bar'), 'b')
      eq(state:get('baz'), {
        test1 = 1,
        test2 = 2,
      })
    end)

    it(
      'should not change the state attribute if no values are present',
      function()
        local state = Config:new(initial_state)
        for i = 10, 1, -1 do
          assert.has_error(function()
            state:set(i, i)
          end)
        end
        eq(state, {
          data = initial_state,
        })
      end
    )
  end)

  describe('assign', function()
    it('should return unmodified state when nil value is passed', function()
      local initial = { foo = true }
      local state = Config:new(initial)
      state:assign(nil)
      eq(state, {
        data = initial,
      })
    end)

    it('should assign tables which are lists', function()
      local initial = {
        is_list = { 1, 2, 3, 4, 5 },
        isnt_list = { a = 1, b = 2 },
      }
      local state = Config:new(initial)
      state:assign({
        is_list = { 'a', 'b' },
        isnt_list = { a = 1, b = 2 },
      })
      eq(state, {
        data = {
          is_list = { 'a', 'b' },
          isnt_list = { a = 1, b = 2 },
        },
      })
    end)

    it('should successfully assign nested objects', function()
      local initial = {
        foo = true,
        bar = {
          baz = {
            a = {
              b = {},
            },
            foo = {
              bar = {
                baz = true,
              },
              a = {
                c = 4,
              },
            },
          },
        },
      }
      local state = Config:new(initial)
      state:assign({
        foo = false,
        bar = {
          baz = {
            foo = {
              bar = {
                baz = false,
              },
            },
          },
        },
      })
      local data = {
        foo = false,
        bar = {
          baz = {
            a = {
              b = {},
            },
            foo = {
              bar = {
                baz = false,
              },
              a = {
                c = 4,
              },
            },
          },
        },
      }
      eq(state, {
        data = data,
      })
    end)
  end)
end)
