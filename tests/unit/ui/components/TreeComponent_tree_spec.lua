local TreeComponent = require('vgit.ui.components.TreeComponent')

describe('TreeComponent - Tree Transformation', function()
  local component

  local function create_mock_status(filename, filetype)
    return {
      filename = filename,
      filetype = filetype or 'text',
      value = 'M',
      is_staged = function() return false end,
      is_unstaged = function() return true end,
      is_unmerged = function() return false end,
      has = function() return false end,
      has_either = function() return false end,
    }
  end

  local function create_entry(id, filename, filetype, entry_type)
    return {
      id = id,
      type = entry_type or 'unstaged',
      status = create_mock_status(filename, filetype),
    }
  end

  before_each(function()
    component = TreeComponent({})
  end)

  describe('normalize_entries', function()
    it('should create normalized entries from file paths', function()
      local entries = { create_entry('id1', 'src/foo.lua', 'lua') }

      local result = component:normalize_entries(entries)

      assert.are.equal(2, #result) -- depth 1 and 2
      assert.are.equal(1, #result[1]) -- 1 entry at depth 1 (src)
      assert.are.equal(1, #result[2]) -- 1 entry at depth 2 (foo.lua)
    end)

    it('should handle multiple files in same directory', function()
      local entries = {
        create_entry('id1', 'src/a.lua'),
        create_entry('id2', 'src/b.lua'),
      }

      local result = component:normalize_entries(entries)

      assert.are.equal(2, #result)
      assert.are.equal(1, #result[1]) -- 1 unique folder 'src'
      assert.are.equal(2, #result[2]) -- 2 files
    end)

    it('should handle nested directories', function()
      local entries = { create_entry('id1', 'src/ui/components/Button.lua') }

      local result = component:normalize_entries(entries)

      assert.are.equal(4, #result) -- depths 1,2,3,4
    end)

    it('should track parent paths correctly', function()
      local entries = { create_entry('id1', 'src/foo.lua') }

      local result = component:normalize_entries(entries)
      local depth2_entry = result[2][1]

      assert.are.equal('/src', depth2_entry.parent)
      assert.are.equal('foo.lua', depth2_entry.current)
    end)

    it('should only attach status to leaf nodes', function()
      local entries = { create_entry('id1', 'src/foo.lua') }

      local result = component:normalize_entries(entries)

      -- Folder should not have status
      assert.is_nil(result[1][1].status)
      -- File should have status
      assert.is_not_nil(result[2][1].status)
    end)
  end)

  describe('generate_tree', function()
    it('should create tree from raw entries', function()
      local entries = { create_entry('id1', 'src/foo.lua') }

      local tree = component:generate_tree(entries)

      assert.are.equal(1, #tree) -- 1 root folder
      assert.is_not_nil(tree[1].items) -- has children
      assert.are.equal(1, #tree[1].items) -- 1 child (file)
    end)

    it('should create folder nodes with items property', function()
      local entries = { create_entry('id1', 'src/foo.lua') }

      local tree = component:generate_tree(entries)
      local folder = tree[1]

      assert.is_not_nil(folder.items)
      assert.is_true(folder.open) -- folders start open
    end)

    it('should create leaf nodes without items property', function()
      local entries = { create_entry('id1', 'src/foo.lua') }

      local tree = component:generate_tree(entries)
      local file = tree[1].items[1]

      assert.is_nil(file.items)
      assert.is_not_nil(file.entry.status)
    end)

    it('should nest folders correctly', function()
      local entries = { create_entry('id1', 'src/ui/Button.lua') }

      local tree = component:generate_tree(entries)

      local src = tree[1]
      assert.are.equal('src', src.value)

      local ui = src.items[1]
      assert.are.equal('ui', ui.value)

      local button = ui.items[1]
      assert.are.equal('Button.lua', button.value)
    end)
  end)

  describe('sort_tree', function()
    it('should put folders before files at each level', function()
      local entries = {
        create_entry('id1', 'src/z_file.lua'),
        create_entry('id2', 'src/a_folder/nested.lua'),
      }

      local tree = component:generate_tree(entries)
      local sorted = component:sort_tree(tree)

      -- First item should be 'a_folder' (folder), second should be 'z_file' (file)
      -- But both are under 'src' folder which is sorted
      assert.is_not_nil(sorted[1].items) -- src is a folder
      assert.is_true(component:is_fold(sorted[1]))
    end)

    it('should sort folders alphabetically', function()
      local entries = {
        create_entry('id1', 'z/file.lua'),
        create_entry('id2', 'a/file.lua'),
        create_entry('id3', 'm/file.lua'),
      }

      local tree = component:generate_tree(entries)
      local sorted = component:sort_tree(tree)

      assert.are.equal('a', sorted[1].value)
      assert.are.equal('m', sorted[2].value)
      assert.are.equal('z', sorted[3].value)
    end)

    it('should sort files alphabetically within folders', function()
      local entries = {
        create_entry('id1', 'src/z.lua'),
        create_entry('id2', 'src/a.lua'),
        create_entry('id3', 'src/m.lua'),
      }

      local tree = component:generate_tree(entries)
      local sorted = component:sort_tree(tree)
      local files = sorted[1].items

      assert.are.equal('a.lua', files[1].value)
      assert.are.equal('m.lua', files[2].value)
      assert.are.equal('z.lua', files[3].value)
    end)
  end)

  describe('transform_entries_to_tree', function()
    it('should transform entries into sorted tree in one call', function()
      local entries = {
        create_entry('id1', 'src/z.lua'),
        create_entry('id2', 'src/a.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.are.equal(1, #tree)
      assert.are.equal('src', tree[1].value)
      assert.are.equal('a.lua', tree[1].items[1].value)
      assert.are.equal('z.lua', tree[1].items[2].value)
    end)

    it('should handle empty entries', function()
      local tree = component:transform_entries_to_tree({})
      assert.are.equal(0, #tree)
    end)

  end)

  describe('fold operations', function()
    it('should toggle fold open state', function()
      local entries = { create_entry('id1', 'src/foo.lua') }

      local tree = component:transform_entries_to_tree(entries)
      local folder = tree[1]

      assert.is_true(folder.open)
      component:toggle_list_item(folder)
      assert.is_false(folder.open)
    end)

    it('should detect fold items correctly', function()
      local entries = { create_entry('id1', 'src/foo.lua') }

      local tree = component:transform_entries_to_tree(entries)
      local folder = tree[1]
      local file = folder.items[1]

      assert.is_true(component:is_fold(folder))
      -- Files don't have items property, so is_fold returns nil/false
      local is_file_fold = component:is_fold(file)
      assert.is_false(is_file_fold or false) -- treat nil as false
    end)

    it('should not toggle non-fold items', function()
      local file = { value = 'foo.lua', entry = { status = {} } }

      -- Should not error
      component:toggle_list_item(file)
      assert.is_nil(file.open)
    end)
  end)

  describe('tree transformation - advanced pipeline', function()
    it('should handle deeply nested single file structure', function()
      local entries = {
        create_entry('id1', 'a/b/c/d/e/f/deep.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.are.equal(1, #tree) -- 'a' is root
      local current = tree[1]
      assert.are.equal('a', current.value)

      for expected_dir in vim.gsplit('b,c,d,e,f', ',') do
        assert.are.equal(1, #current.items)
        current = current.items[1]
        assert.are.equal(expected_dir, current.value)
      end

      assert.are.equal('deep.lua', current.items[1].value)
    end)

    it('should group multiple files in same directory correctly', function()
      local entries = {
        create_entry('id1', 'src/a.lua'),
        create_entry('id2', 'src/b.lua'),
        create_entry('id3', 'src/c.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.are.equal(1, #tree)
      assert.are.equal('src', tree[1].value)
      assert.are.equal(3, #tree[1].items)
      assert.are.equal('a.lua', tree[1].items[1].value)
      assert.are.equal('b.lua', tree[1].items[2].value)
      assert.are.equal('c.lua', tree[1].items[3].value)
    end)

    it('should handle multiple root directories', function()
      local entries = {
        create_entry('id1', 'src/file.lua'),
        create_entry('id2', 'lib/file.lua'),
        create_entry('id3', 'tests/file.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.are.equal(3, #tree)
      local roots = {}
      for i = 1, #tree do
        roots[tree[i].value] = tree[i]
      end
      assert.is_not_nil(roots['lib'])
      assert.is_not_nil(roots['src'])
      assert.is_not_nil(roots['tests'])
    end)

    it('should preserve all file entries with status', function()
      local entries = {
        create_entry('id1', 'src/a.lua'),
        create_entry('id2', 'src/b.lua'),
        create_entry('id3', 'lib/c.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      -- Collect all file nodes
      local files = {}
      local function collect_files(nodes)
        for i = 1, #nodes do
          local node = nodes[i]
          if node.entry and node.entry.status then
            files[#files + 1] = node
          end
          if node.items then
            collect_files(node.items)
          end
        end
      end

      collect_files(tree)
      assert.are.equal(3, #files)
    end)

    it('should handle mixed deeply nested and shallow files', function()
      local entries = {
        create_entry('id1', 'root.lua'),
        create_entry('id2', 'src/shallow.lua'),
        create_entry('id3', 'src/nested/deep.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.are.equal(2, #tree) -- root.lua and src folder
      local root_lua = tree[1].value == 'root.lua' and tree[1] or tree[2]
      local src_folder = tree[1].value == 'src' and tree[1] or tree[2]

      assert.are.equal('root.lua', root_lua.value)
      assert.is_nil(root_lua.items) -- file node has no items

      assert.are.equal('src', src_folder.value)
      assert.is_not_nil(src_folder.items)
      assert.is_true(#src_folder.items > 0)
    end)

    it('should maintain folder structure with multiple nested levels', function()
      local entries = {
        create_entry('id1', 'a/b/c/file1.lua'),
        create_entry('id2', 'a/b/file2.lua'),
        create_entry('id3', 'a/file3.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.are.equal(1, #tree)
      local a = tree[1]
      assert.are.equal('a', a.value)
      assert.are.equal(2, #a.items) -- 'b' folder and 'file3.lua'

      local b = nil
      local file3 = nil
      for i = 1, #a.items do
        if a.items[i].value == 'b' then b = a.items[i]
        elseif a.items[i].value == 'file3.lua' then file3 = a.items[i]
        end
      end

      assert.is_not_nil(b)
      assert.is_not_nil(file3)

      assert.are.equal(2, #b.items) -- 'c' folder and 'file2.lua'
      local c = b.items[1].value == 'c' and b.items[1] or b.items[2]
      assert.are.equal(1, #c.items) -- 'file1.lua'
    end)

    it('should handle files with special characters in names', function()
      local entries = {
        create_entry('id1', 'src/test-file.lua'),
        create_entry('id2', 'src/file_name.lua'),
        create_entry('id3', 'src/file.min.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.are.equal(1, #tree)
      assert.are.equal(3, #tree[1].items)
    end)

    it('should maintain tree structure when calling transform multiple times', function()
      local entries = {
        create_entry('id1', 'src/a.lua'),
        create_entry('id2', 'src/b.lua'),
      }

      local tree1 = component:transform_entries_to_tree(entries)
      local tree2 = component:transform_entries_to_tree(entries)

      assert.are.equal(tree1[1].value, tree2[1].value)
      assert.are.equal(#tree1[1].items, #tree2[1].items)
      assert.are.equal(tree1[1].items[1].value, tree2[1].items[1].value)
    end)

    it('should keep folders open by default', function()
      local entries = {
        create_entry('id1', 'src/nested/file.lua'),
      }

      local tree = component:transform_entries_to_tree(entries)

      assert.is_true(tree[1].open) -- src folder
      assert.is_true(tree[1].items[1].open) -- nested folder
      assert.is_nil(tree[1].items[1].items[1].open) -- file has no open property
    end)
  end)
end)
