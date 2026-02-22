local env = require('vgit.core.env')

local eq = assert.are.same

describe('env:', function()
  before_each(function()
    env._reset()
  end)

  describe('register_module', function()
    it('should set LC_ALL and LANGUAGE to C', function()
      env.register_module()

      eq(env.get('LC_ALL'), 'C')
      eq(env.get('LANGUAGE'), 'C')
    end)

    it('should be idempotent', function()
      env.register_module()
      env.set('LC_ALL', 'foo')
      env.register_module()

      eq(env.get('LC_ALL'), 'foo')
    end)
  end)

  describe('set', function()
    it('should throw an error if key is not a string', function()
      assert.has_error(function()
        env.set(3, 'value')
      end)
    end)

    it('should throw an error if type is not a string', function()
      assert.has_error(function()
        env.set('string', function() end)
      end)
      assert.has_error(function()
        env.set(3, {})
      end)
      assert.has_error(function()
        env.set(3, { 'hello' })
      end)
    end)

    it('should set a value', function()
      env.set('foo', 'bar')
      env.set('bar', 3)
      env.set('baz', true)
      assert(env.get('foo'))
      assert(env.get('bar'))
      assert(env.get('baz'))
    end)
  end)

  describe('get', function()
    it('should throw an error if type is not a string', function()
      assert.has_error(function()
        env.get(3)
      end)
    end)

    it('should retrieve a value that has been set', function()
      eq(env.set('foo', 'bar').get('foo'), 'bar')
    end)
  end)

  describe('unset', function()
    it('should throw an error if type is not a string', function()
      assert.has_error(function()
        env.unset(3)
      end)
    end)

    it('should throw an error if value is not set', function()
      assert.has_error(function()
        env.unset('hello')
      end)
    end)

    it('should unset a key that has been set', function()
      eq(env.set('foo', 'bar').get('foo'), 'bar')
      env.unset('foo')
      eq(env.get('foo'), nil)
    end)
  end)

  describe('get_all', function()
    it('should return all environment variables as table', function()
      env.register_module()
      env.set('TEST_VAR', 'test_value')
      local all = env.get_all()
      assert.is_table(all)
      local found = false
      for _, v in ipairs(all) do
        if v == 'TEST_VAR=test_value' then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)
end)
