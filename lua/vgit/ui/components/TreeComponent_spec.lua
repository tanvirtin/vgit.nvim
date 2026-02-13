local TreeComponent = require('vgit.ui.components.TreeComponent')

local eq = assert.are.same

describe('TreeComponent:', function()
  local component

  before_each(function()
    component = TreeComponent({})
  end)

  describe('filename extraction', function()
    it('should extract filename from simple path', function()
      local full_path = 'file.lua'
      local parts = vim.split(full_path, '/')
      local filename = parts[#parts] or full_path
      assert.are.equal('file.lua', filename)
    end)

    it('should extract filename from nested path', function()
      local full_path = 'src/components/file.lua'
      local parts = vim.split(full_path, '/')
      local filename = parts[#parts] or full_path
      assert.are.equal('file.lua', filename)
    end)

    it('should handle deeply nested paths', function()
      local full_path = 'a/b/c/d/e/file.lua'
      local parts = vim.split(full_path, '/')
      local filename = parts[#parts] or full_path
      assert.are.equal('file.lua', filename)
    end)
  end)

  describe('get_display_name', function()
    it('should extract filename from simple path', function()
      local result = component:get_display_name('file.lua')
      assert.are.equal('file.lua', result)
    end)

    it('should extract filename from nested path', function()
      local result = component:get_display_name('src/components/file.lua')
      assert.are.equal('file.lua', result)
    end)

    it('should handle nil filename', function()
      local result = component:get_display_name(nil)
      assert.is_nil(result)
    end)

    it('should handle deeply nested paths', function()
      local result = component:get_display_name('a/b/c/d/e/file.lua')
      assert.are.equal('file.lua', result)
    end)
  end)

  describe('get_status_highlight', function()
    local function create_mock_status(config)
      config = config or {}
      return {
        is_staged = function() return config.is_staged or false end,
        is_unstaged = function() return config.is_unstaged or false end,
        is_unmerged = function() return config.is_unmerged or false end,
        has = function(_, code)
          if config.has_codes then
            for _, c in ipairs(config.has_codes) do
              if c == code then return true end
            end
          end
          return false
        end,
        has_either = function(_, code)
          if config.has_either_codes then
            for _, c in ipairs(config.has_either_codes) do
              if c == code then return true end
            end
          end
          return false
        end,
      }
    end

    it('should return GitSignsAdd for staged added files', function()
      local status = create_mock_status({
        is_staged = true,
        has_codes = { 'A*' },
      })
      local hl = component:get_status_highlight(status)
      assert.are.equal('GitSignsAdd', hl)
    end)

    it('should return GitSignsDelete for staged deleted files', function()
      local status = create_mock_status({
        is_staged = true,
        has_codes = { 'D*' },
      })
      local hl = component:get_status_highlight(status)
      assert.are.equal('GitSignsDelete', hl)
    end)

    it('should return GitSignsAdd for unstaged new files', function()
      local status = create_mock_status({
        is_unstaged = true,
        has_codes = { '??' },
      })
      local hl = component:get_status_highlight(status)
      assert.are.equal('GitSignsAdd', hl)
    end)

    it('should return GitSignsDelete for unstaged deleted files', function()
      local status = create_mock_status({
        is_unstaged = true,
        has_codes = { '*D' },
      })
      local hl = component:get_status_highlight(status)
      assert.are.equal('GitSignsDelete', hl)
    end)

    it('should return GitSignsChange for unmerged files', function()
      local status = create_mock_status({
        is_unmerged = true,
      })
      local hl = component:get_status_highlight(status)
      assert.are.equal('GitSignsChange', hl)
    end)

    it('should return GitLineNr as fallback', function()
      local status = create_mock_status({})
      local hl = component:get_status_highlight(status)
      assert.are.equal('GitLineNr', hl)
    end)
  end)

  describe('state management', function()
    it('should set list', function()
      local list = { { value = 'test' } }
      component:set_list(list)
      assert.are.equal(list, component.state.list)
    end)

    it('should set title', function()
      component:set_title('Test Title')
      assert.are.equal('Test Title', component.state.title)
    end)

    it('should chain set_list', function()
      local result = component:set_list({})
      assert.are.equal(component, result)
    end)

    it('should chain set_title', function()
      local result = component:set_title('Title')
      assert.are.equal(component, result)
    end)
  end)

  describe('get_parent_folder', function()
    it('should return empty string and count 1 for first index', function()
      local parent, depth = component:get_parent_folder({ 'src', 'file.lua' }, 1)
      assert.are.equal('', parent)
      assert.are.equal(1, depth)
    end)

    it('should return parent path for second index', function()
      local parent, depth = component:get_parent_folder({ 'src', 'file.lua' }, 2)
      assert.are.equal('/src', parent)
      assert.are.equal(2, depth)
    end)

    it('should return nested parent path', function()
      local parent, depth = component:get_parent_folder({ 'a', 'b', 'c', 'file.lua' }, 3)
      assert.are.equal('/a/b', parent)
      assert.are.equal(3, depth)
    end)
  end)

  describe('create_node - file nodes', function()
    local function create_mock_status(filename, filetype)
      return {
        filename = filename or 'test.lua',
        filetype = filetype or 'lua',
        value = 'M ',
        is_staged = function() return false end,
        is_unstaged = function() return true end,
        is_unmerged = function() return false end,
        has = function() return false end,
        has_either = function() return false end,
      }
    end

    local function create_file_entry(filename, filetype)
      return {
        id = 'test-id',
        type = 'unstaged',
        status = create_mock_status(filename, filetype),
      }
    end

    it('should create node with id from entry', function()
      local entry = create_file_entry()
      local node = component:create_node(entry)
      assert.are.equal('test-id', node.id)
    end)

    it('should extract display name from full path', function()
      local entry = create_file_entry('src/components/Button.lua')
      local node = component:create_node(entry)
      assert.are.equal('Button.lua', node.value)
    end)

    it('should set entry reference', function()
      local entry = create_file_entry()
      local node = component:create_node(entry)
      assert.are.equal(entry, node.entry)
    end)

    it('should not have items array for file nodes', function()
      local entry = create_file_entry()
      local node = component:create_node(entry)
      assert.is_nil(node.items)
    end)
  end)

  describe('create_node - folder nodes', function()
    local function create_folder_entry(segment_name)
      return {
        id = 'folder-id',
        type = 'folder',
        current = segment_name or 'src',
        parent = '/',
        status = nil,
      }
    end

    it('should create node with folder entry', function()
      local entry = create_folder_entry('components')
      local node = component:create_node(entry)
      assert.is_not_nil(node)
    end)

    it('should use current segment as folder display name', function()
      local entry = create_folder_entry('src')
      local node = component:create_node(entry)
      assert.are.equal('src', node.value)
    end)

    it('should set open to true by default', function()
      local entry = create_folder_entry()
      local node = component:create_node(entry)
      assert.is_true(node.open)
    end)

    it('should have empty items array', function()
      local entry = create_folder_entry()
      local node = component:create_node(entry)
      assert.are.equal(0, #node.items)
    end)

    it('should use fallback value for unknown folders', function()
      local entry = create_folder_entry()
      entry.current = nil
      local node = component:create_node(entry)
      assert.are.equal('Unknown', node.value)
    end)
  end)
end)
