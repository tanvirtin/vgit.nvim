local CustomHunkGenerator = require('vgit.core.diff.hunks.CustomHunkGenerator')

describe('CustomHunkGenerator', function()
  local generator

  before_each(function()
    generator = CustomHunkGenerator()
  end)

  describe('generate', function()
    it('should return empty for no opts', function()
      local result = generator:generate({ 'a', 'b' })
      assert.are.same({}, result)
    end)

    it('should dispatch to untracked when opts.untracked', function()
      local result = generator:generate({ 'a', 'b' }, { untracked = true })
      assert.are.equal(1, #result)
      assert.are.equal('add', result[1].type)
    end)

    it('should dispatch to deleted when opts.deleted', function()
      local result = generator:generate({ 'a', 'b' }, { deleted = true })
      assert.are.equal(1, #result)
      assert.are.equal('remove', result[1].type)
    end)
  end)

  describe('_generate_untracked', function()
    it('should return empty for nil lines', function()
      local result = generator:_generate_untracked(nil)
      assert.are.same({}, result)
    end)

    it('should return empty for empty lines', function()
      local result = generator:_generate_untracked({})
      assert.are.same({}, result)
    end)

    it('should create add hunk spanning all lines', function()
      local lines = { 'line1', 'line2', 'line3' }
      local result = generator:_generate_untracked(lines)

      assert.are.equal(1, #result)
      local hunk = result[1]
      assert.are.equal('add', hunk.type)
      assert.are.equal(1, hunk.top)
      assert.are.equal(3, hunk.bot)
      assert.are.equal(3, #hunk.diff)
      assert.are.equal(3, hunk.stat.added)
      assert.are.equal(0, hunk.stat.removed)
    end)

    it('should prefix diff lines with +', function()
      local result = generator:_generate_untracked({ 'hello' })
      assert.are.equal('+hello', result[1].diff[1])
    end)

    it('should set correct header', function()
      local result = generator:_generate_untracked({ 'a', 'b' })
      assert.are.equal('@@ -0,0 +1,2 @@', result[1].header)
    end)
  end)

  describe('_generate_deleted', function()
    it('should return empty for nil lines', function()
      local result = generator:_generate_deleted(nil)
      assert.are.same({}, result)
    end)

    it('should return empty for empty lines', function()
      local result = generator:_generate_deleted({})
      assert.are.same({}, result)
    end)

    it('should create remove hunk spanning all lines', function()
      local lines = { 'line1', 'line2', 'line3' }
      local result = generator:_generate_deleted(lines)

      assert.are.equal(1, #result)
      local hunk = result[1]
      assert.are.equal('remove', hunk.type)
      assert.are.equal(1, hunk.top)
      assert.are.equal(3, hunk.bot)
      assert.are.equal(3, #hunk.diff)
      assert.are.equal(0, hunk.stat.added)
      assert.are.equal(3, hunk.stat.removed)
    end)

    it('should prefix diff lines with -', function()
      local result = generator:_generate_deleted({ 'hello' })
      assert.are.equal('-hello', result[1].diff[1])
    end)

    it('should set correct header', function()
      local result = generator:_generate_deleted({ 'a', 'b' })
      assert.are.equal('@@ -1,2 +0,0 @@', result[1].header)
    end)
  end)
end)
