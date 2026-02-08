local eq = assert.are.same

describe('FileDiffView', function()
  local FileDiffView

  before_each(function()
    FileDiffView = require('vgit.features.screens.FileDiffView')
  end)

  describe('create() validation', function()
    it('should reject nil data', function()
      local view = FileDiffView()
      local result = view:create(nil)
      assert.is_false(result)
    end)

    it('should reject non-table data', function()
      local view = FileDiffView()
      local result = view:create('not a table')
      assert.is_false(result)
    end)

    it('should reject data without diff', function()
      local view = FileDiffView()
      local result = view:create({
        filename = 'test.lua',
      })
      assert.is_false(result)
    end)

    it('should reject data with empty diff', function()
      local view = FileDiffView()
      local result = view:create({
        diff = {},
        filename = 'test.lua',
      })
      assert.is_false(result)
    end)

    it('should reject data without filename', function()
      local view = FileDiffView()
      local result = view:create({
        diff = { lines = { 'a' }, hunks = {}, marks = {} },
      })
      assert.is_false(result)
    end)

    it('should reject data with whitespace-only filename', function()
      local view = FileDiffView()
      local result = view:create({
        diff = { lines = { 'a' }, hunks = {}, marks = {} },
        filename = '   ',
      })
      assert.is_false(result)
    end)

    it('should reject data with non-string filetype', function()
      local view = FileDiffView()
      local result = view:create({
        diff = { lines = { 'a' }, hunks = {}, marks = {} },
        filename = 'test.lua',
        filetype = 123,
      })
      assert.is_false(result)
    end)
  end)

end)
