local eq = assert.are.same

describe('SearchFilter:', function()
  local SearchFilter

  before_each(function()
    package.loaded['vgit.ui.components.SearchComponent.SearchFilter'] = nil
    SearchFilter = require('vgit.ui.components.SearchComponent.SearchFilter')
  end)

  describe('filter', function()
    it('should return all items when query is empty string', function()
      local filter = SearchFilter()
      local items = {
        { label = 'main' },
        { label = 'develop' },
        { label = 'feature/auth' },
      }
      eq(items, filter:filter(items, ''))
    end)

    it('should return all items when query is nil', function()
      local filter = SearchFilter()
      local items = {
        { label = 'main' },
        { label = 'develop' },
      }
      eq(items, filter:filter(items, nil))
    end)

    it('should filter items by substring match on label', function()
      local filter = SearchFilter()
      local items = {
        { label = 'main' },
        { label = 'develop' },
        { label = 'feature/auth' },
        { label = 'feature/login' },
      }
      local result = filter:filter(items, 'feature')
      eq(2, #result)
      eq('feature/auth', result[1].label)
      eq('feature/login', result[2].label)
    end)

    it('should be case insensitive', function()
      local filter = SearchFilter()
      local items = {
        { label = 'Main' },
        { label = 'DEVELOP' },
        { label = 'feature' },
      }

      local result = filter:filter(items, 'main')
      eq(1, #result)
      eq('Main', result[1].label)

      result = filter:filter(items, 'FEATURE')
      eq(1, #result)
      eq('feature', result[1].label)

      result = filter:filter(items, 'dev')
      eq(1, #result)
      eq('DEVELOP', result[1].label)
    end)

    it('should return empty table when no matches found', function()
      local filter = SearchFilter()
      local items = {
        { label = 'main' },
        { label = 'develop' },
      }
      local result = filter:filter(items, 'xyz')
      eq({}, result)
    end)

    it('should return empty table when items is empty', function()
      local filter = SearchFilter()
      local result = filter:filter({}, 'query')
      eq({}, result)
    end)

    it('should return empty table when items is nil', function()
      local filter = SearchFilter()
      local result = filter:filter(nil, 'query')
      eq({}, result)
    end)

    it('should preserve item properties in filtered results', function()
      local filter = SearchFilter()
      local obj = { id = 1 }
      local items = {
        { label = 'main', description = 'default branch', value = obj },
        { label = 'develop', description = 'dev branch' },
      }
      local result = filter:filter(items, 'main')
      eq(1, #result)
      eq('main', result[1].label)
      eq('default branch', result[1].description)
      eq(obj, result[1].value)
    end)

    it('should match partial substrings', function()
      local filter = SearchFilter()
      local items = {
        { label = 'feature/authentication' },
        { label = 'feature/authorization' },
        { label = 'bugfix/auth-error' },
      }
      local result = filter:filter(items, 'auth')
      eq(3, #result)
    end)

    it('should use plain find (no pattern matching)', function()
      local filter = SearchFilter()
      local items = {
        { label = 'test.file' },
        { label = 'testXfile' },
      }
      -- '.' in plain find should match literal dot, not any character
      local result = filter:filter(items, 'test.file')
      eq(1, #result)
      eq('test.file', result[1].label)
    end)
  end)
end)
