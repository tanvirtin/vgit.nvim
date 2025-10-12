local Buffer = require('vgit.core.Buffer')
local WindowManager = require('vgit.ui.window.WindowManager')
local LensWindowHandle = require('vgit.ui.window.LensWindowHandle')

describe('WindowManager:', function()
  local manager
  local buffer

  before_each(function()
    manager = WindowManager()
    buffer = Buffer():create(false, true)
  end)

  after_each(function()
    if manager then manager:close_all() end
    if buffer and buffer:is_valid() then buffer:delete() end
  end)

  describe('constructor', function()
    it('should initialize with empty handles', function()
      assert.are.equal(0, manager:count())
    end)

    it('should start with ID counter at 1', function()
      assert.are.equal(1, manager.next_id)
    end)
  end)

  describe('register', function()
    it('should register a handle and return an ID', function()
      local handle = LensWindowHandle()
      local id = manager:register(handle)

      assert.are.equal(1, id)
      assert.are.equal(1, manager:count())
    end)

    it('should increment ID for each registration', function()
      local handle1 = LensWindowHandle()
      local handle2 = LensWindowHandle()

      local id1 = manager:register(handle1)
      local id2 = manager:register(handle2)

      assert.are.equal(1, id1)
      assert.are.equal(2, id2)
      assert.are.equal(2, manager:count())
    end)
  end)

  describe('get', function()
    it('should retrieve a registered handle', function()
      local handle = LensWindowHandle()
      local id = manager:register(handle)

      assert.are.equal(handle, manager:get(id))
    end)

    it('should return nil for unregistered ID', function()
      assert.is_nil(manager:get(999))
    end)
  end)

  describe('has', function()
    it('should return true for registered ID', function()
      local handle = LensWindowHandle()
      local id = manager:register(handle)

      assert.is_true(manager:has(id))
    end)

    it('should return false for unregistered ID', function()
      assert.is_false(manager:has(999))
    end)
  end)

  describe('unregister', function()
    it('should unregister a handle', function()
      local handle = LensWindowHandle()
      local id = manager:register(handle)

      assert.is_true(manager:has(id))
      manager:unregister(id)
      assert.is_false(manager:has(id))
    end)
  end)

  describe('close', function()
    it('should close and unregister a window', function()
      local handle = LensWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      local id = manager:register(handle)
      assert.is_true(handle:is_valid())

      manager:close(id)
      assert.is_false(manager:has(id))
      assert.is_false(handle:is_valid())
    end)

    it('should not error when closing unregistered ID', function()
      assert.has_no_error(function()
        manager:close(999)
      end)
    end)
  end)

  describe('close_all', function()
    it('should close all registered windows', function()
      local handle1 = LensWindowHandle()
      local handle2 = LensWindowHandle()

      handle1:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      local buffer2 = Buffer():create(false, true)
      handle2:open(buffer2, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      manager:register(handle1)
      manager:register(handle2)

      assert.are.equal(2, manager:count())

      manager:close_all()

      assert.are.equal(0, manager:count())
      assert.is_false(handle1:is_valid())
      assert.is_false(handle2:is_valid())

      if buffer2:is_valid() then buffer2:delete() end
    end)
  end)

  describe('cleanup', function()
    it('should remove invalid handles', function()
      local handle1 = LensWindowHandle()
      local handle2 = LensWindowHandle()

      handle1:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      manager:register(handle1)
      manager:register(handle2) -- Not opened, invalid

      assert.are.equal(2, manager:count())

      manager:cleanup()

      assert.are.equal(1, manager:count())

      handle1:close()
    end)
  end)

  describe('each', function()
    it('should iterate over all handles', function()
      local handle1 = LensWindowHandle()
      local handle2 = LensWindowHandle()

      manager:register(handle1)
      manager:register(handle2)

      local count = 0
      manager:each(function(id, handle)
        count = count + 1
        assert.is_not_nil(id)
        assert.is_not_nil(handle)
      end)

      assert.are.equal(2, count)
    end)
  end)

  describe('find', function()
    it('should find a handle by predicate', function()
      local handle1 = LensWindowHandle()
      local handle2 = LensWindowHandle()

      local id1 = manager:register(handle1)
      manager:register(handle2)

      local found_id, found_handle = manager:find(function(id, handle)
        return id == id1
      end)

      assert.are.equal(id1, found_id)
      assert.are.equal(handle1, found_handle)
    end)

    it('should return nil when not found', function()
      local id, handle = manager:find(function()
        return false
      end)

      assert.is_nil(id)
      assert.is_nil(handle)
    end)
  end)
end)
