local DepthTree = require('vgit.ui.components.TreeComponent.DepthTree')
local fs = require('vgit.core.fs')

local eq = assert.are.same

describe('DepthTree:', function()
  local sep = fs.sep

  describe('get_parent_folder', function()
    it('should return empty string and depth 1 for first segment', function()
      local tree = DepthTree()
      local folder, depth = tree:get_parent_folder({ 'src', 'lua', 'init.lua' }, 1)
      assert.are.equal('', folder)
      assert.are.equal(1, depth)
    end)

    it('should return parent folder for second segment', function()
      local tree = DepthTree()
      local folder, depth = tree:get_parent_folder({ 'src', 'lua', 'init.lua' }, 2)
      assert.are.equal(sep .. 'src', folder)
      assert.are.equal(2, depth)
    end)

    it('should return nested parent for third segment', function()
      local tree = DepthTree()
      local folder, depth = tree:get_parent_folder({ 'src', 'lua', 'init.lua' }, 3)
      assert.are.equal(sep .. 'src' .. sep .. 'lua', folder)
      assert.are.equal(3, depth)
    end)

    it('should handle single segment', function()
      local tree = DepthTree()
      local folder, depth = tree:get_parent_folder({ 'file.lua' }, 1)
      assert.are.equal('', folder)
      assert.are.equal(1, depth)
    end)
  end)

  describe('create_node', function()
    it('should create file node when entry has status', function()
      local tree = DepthTree()
      local entry = {
        id = 1,
        current = 'file.lua',
        status = { filename = 'file.lua' },
      }
      local node = tree:create_node(entry)
      assert.are.equal(1, node.id)
      assert.are.equal('file.lua', node.value)
      assert.is_nil(node.items)
    end)

    it('should create folder node when entry has no status', function()
      local tree = DepthTree()
      local entry = {
        id = 1,
        current = 'src',
      }
      local node = tree:create_node(entry)
      eq({}, node.items)
      assert.is_true(node.open)
      assert.are.equal('src', node.value)
    end)
  end)

  describe('from_entries', function()
    it('should build tree from single flat file entry', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'file.lua' }, type = 'changed' },
      })
      local result = tree:value()
      assert.are.equal(1, #result)
      assert.are.equal('file.lua', result[1].value)
    end)

    it('should build tree with nested directory structure', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'src' .. sep .. 'init.lua' }, type = 'changed' },
      })
      local result = tree:value()
      -- Should have 'src' folder at root
      assert.are.equal(1, #result)
      assert.are.equal('src', result[1].value)
      assert.is_not_nil(result[1].items)
      -- With 'init.lua' inside
      assert.are.equal(1, #result[1].items)
      assert.are.equal('init.lua', result[1].items[1].value)
    end)

    it('should group files under same directory', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'src' .. sep .. 'a.lua' }, type = 'changed' },
        { id = 2, status = { filename = 'src' .. sep .. 'b.lua' }, type = 'changed' },
      })
      local result = tree:value()
      assert.are.equal(1, #result)
      assert.are.equal('src', result[1].value)
      assert.are.equal(2, #result[1].items)
    end)

    it('should handle deeply nested paths', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'a' .. sep .. 'b' .. sep .. 'c' .. sep .. 'file.lua' }, type = 'changed' },
      })
      local result = tree:value()
      assert.are.equal(1, #result)
      assert.are.equal('a', result[1].value)
      assert.are.equal(1, #result[1].items)
      assert.are.equal('b', result[1].items[1].value)
      assert.are.equal(1, #result[1].items[1].items)
      assert.are.equal('c', result[1].items[1].items[1].value)
      assert.are.equal(1, #result[1].items[1].items[1].items)
      assert.are.equal('file.lua', result[1].items[1].items[1].items[1].value)
    end)

    it('should handle multiple root-level files', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'alpha.lua' }, type = 'changed' },
        { id = 2, status = { filename = 'beta.lua' }, type = 'changed' },
      })
      local result = tree:value()
      assert.are.equal(2, #result)
    end)
  end)

  describe('sort', function()
    it('should place folders before files', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'file_a.lua' }, type = 'changed' },
        { id = 2, status = { filename = 'src' .. sep .. 'init.lua' }, type = 'changed' },
        { id = 3, status = { filename = 'file_b.lua' }, type = 'changed' },
      })
      tree:sort()
      local result = tree:value()
      -- First item should be the 'src' folder
      assert.is_not_nil(result[1].items)
      assert.are.equal('src', result[1].value)
      -- Then files
      assert.is_nil(result[2].items)
      assert.is_nil(result[3].items)
    end)

    it('should sort folders alphabetically', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'zeta' .. sep .. 'file.lua' }, type = 'changed' },
        { id = 2, status = { filename = 'alpha' .. sep .. 'file.lua' }, type = 'changed' },
      })
      tree:sort()
      local result = tree:value()
      assert.are.equal('alpha', result[1].value)
      assert.are.equal('zeta', result[2].value)
    end)

    it('should sort files alphabetically', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'z.lua' }, type = 'changed' },
        { id = 2, status = { filename = 'a.lua' }, type = 'changed' },
        { id = 3, status = { filename = 'm.lua' }, type = 'changed' },
      })
      tree:sort()
      local result = tree:value()
      assert.are.equal('a.lua', result[1].value)
      assert.are.equal('m.lua', result[2].value)
      assert.are.equal('z.lua', result[3].value)
    end)

    it('should sort items within nested folders', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'src' .. sep .. 'z.lua' }, type = 'changed' },
        { id = 2, status = { filename = 'src' .. sep .. 'a.lua' }, type = 'changed' },
      })
      tree:sort()
      local result = tree:value()
      local src = result[1]
      assert.are.equal('a.lua', src.items[1].value)
      assert.are.equal('z.lua', src.items[2].value)
    end)
  end)

  describe('find_parent_node', function()
    it('should find parent by path', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'src' .. sep .. 'init.lua' }, type = 'changed' },
      })
      -- The 'src' folder has path = sep .. 'src'
      local parent = tree:find_parent_node({ parent = sep .. 'src' })
      assert.is_not_nil(parent)
      assert.are.equal('src', parent.value)
    end)

    it('should return nil when parent is not found', function()
      local tree = DepthTree()
      tree:from_entries({
        { id = 1, status = { filename = 'file.lua' }, type = 'changed' },
      })
      local parent = tree:find_parent_node({ parent = sep .. 'nonexistent' })
      assert.is_nil(parent)
    end)
  end)
end)
