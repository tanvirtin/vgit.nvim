local lazy = require('vgit.core.lazy')

local eq = assert.are.same

describe('lazy:', function()
  describe('basic functionality', function()
    it('should return a proxy table', function()
      local proxy = lazy('vgit.core.Object')
      assert.is_table(proxy)
      assert.is_true(getmetatable(proxy) ~= nil)
    end)

    it('should return same proxy for same module path', function()
      local proxy1 = lazy('vgit.core.Object')
      local proxy2 = lazy('vgit.core.Object')
      eq(proxy1, proxy2)
    end)

    it('should have index metamethod', function()
      local proxy = lazy('vgit.core.Object')
      local mt = getmetatable(proxy)
      assert.is_not_nil(mt.__index)
    end)

    it('should have call metamethod', function()
      local proxy = lazy('vgit.core.Object')
      local mt = getmetatable(proxy)
      assert.is_not_nil(mt.__call)
    end)

    it('should have newindex metamethod', function()
      local proxy = lazy('vgit.core.Object')
      local mt = getmetatable(proxy)
      assert.is_not_nil(mt.__newindex)
    end)

    it('should return cached proxy on multiple calls', function()
      local proxy1 = lazy('vgit.core.Object')
      local proxy2 = lazy('vgit.core.Object')
      eq(proxy1, proxy2)
    end)
  end)

  describe('deferred loading', function()
    it('should not require module until first property access', function()
      local module_path = 'vgit.core.assertion'

      package.loaded[module_path] = nil

      local proxy = lazy(module_path)

      assert.is_nil(package.loaded[module_path])

      local _ = proxy.assert

      assert.is_not_nil(package.loaded[module_path])
    end)
  end)
end)
