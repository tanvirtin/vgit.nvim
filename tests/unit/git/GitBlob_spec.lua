local GitBlob = require('vgit.git.GitBlob')
local test_repo = require('tests.helpers.test_repo')

describe('GitBlob', function()
  local repo

  before_each(function()
    test_repo.use_driver('git') -- Use GitRepository objects
    repo = test_repo.create_repo({
      initial_commit = true,
      files = { ['init.txt'] = 'initial content' },
    })
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('constructor', function()
    it('creates a blob with repository, filename, and commit', function()
      local blob = GitBlob(repo, 'test.txt', 'HEAD')

      assert.is_not_nil(blob)
      assert.equals('test.txt', blob:get_filename())
      assert.equals('HEAD', blob:get_commit())
    end)

    it('defaults to HEAD if commit not provided', function()
      local blob = GitBlob(repo, 'test.txt')
      assert.equals('HEAD', blob:get_commit())
    end)

    it('errors if repository not provided', function()
      assert.has_error(function()
        GitBlob(nil, 'test.txt')
      end, 'GitBlob: repository is required')
    end)

    it('errors if filename not provided', function()
      assert.has_error(function()
        GitBlob(repo, nil)
      end, 'GitBlob: filename is required')
    end)

    it('errors if filename is empty string', function()
      assert.has_error(function()
        GitBlob(repo, '')
      end, 'GitBlob: filename is required')
    end)
  end)

  describe('exists', function()
    it('returns true if file exists at commit', function()
      test_repo.create_commit(repo, {
        files = { ['exists.txt'] = 'content' },
        message = 'Add exists.txt',
      })

      local blob = GitBlob(repo, 'exists.txt', 'HEAD')
      assert.is_true(blob:exists())
    end)

    it('returns false if file does not exist at commit', function()
      local blob = GitBlob(repo, 'nonexistent.txt', 'HEAD')
      assert.is_false(blob:exists())
    end)

    it('checks existence at specific commit', function()
      test_repo.create_commit(repo, {
        files = { ['timeline.txt'] = 'v1' },
        message = 'Add timeline',
      })
      local first_commit = test_repo.get_head_commit(repo)

      test_repo.delete_file(repo, 'timeline.txt', true)
      test_repo.create_commit(repo, {
        message = 'Delete timeline',
      })

      local blob_old = GitBlob(repo, 'timeline.txt', first_commit)
      assert.is_true(blob_old:exists())

      local blob_head = GitBlob(repo, 'timeline.txt', 'HEAD')
      assert.is_false(blob_head:exists())
    end)
  end)

  describe('content', function()
    it('returns file content as string', function()
      test_repo.create_commit(repo, {
        files = { ['content.txt'] = 'hello world' },
        message = 'Add content',
      })

      local blob = GitBlob(repo, 'content.txt', 'HEAD')
      local content, err = blob:content()

      assert.is_nil(err, 'Should not error when reading content')
      assert.is_not_nil(content, 'Content should not be nil')
      assert.is_string(content, 'Content should be a string')
      assert.equals('hello world', content, 'Content should match exactly')
    end)

    it('returns multiline content', function()
      test_repo.create_commit(repo, {
        files = { ['multiline.txt'] = { 'line 1', 'line 2', 'line 3' } },
        message = 'Add multiline',
      })

      local blob = GitBlob(repo, 'multiline.txt', 'HEAD')
      local content, err = blob:content()

      assert.is_nil(err, 'Should not error when reading multiline content')
      assert.is_not_nil(content, 'Content should not be nil')
      assert.is_string(content, 'Content should be a string')
      assert.is_true(content:match('line 1') ~= nil, 'Content should contain line 1')
      assert.is_true(content:match('line 2') ~= nil, 'Content should contain line 2')
      assert.is_true(content:match('line 3') ~= nil, 'Content should contain line 3')

      -- Verify order is preserved
      local pos1 = content:find('line 1')
      local pos2 = content:find('line 2')
      local pos3 = content:find('line 3')
      assert.is_true(pos1 < pos2, 'line 1 should come before line 2')
      assert.is_true(pos2 < pos3, 'line 2 should come before line 3')
    end)

    it('returns content from specific commit', function()
      test_repo.create_commit(repo, {
        files = { ['versions.txt'] = 'v1' },
        message = 'Version 1',
      })
      local v1_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(v1_commit, 'V1 commit should exist')

      test_repo.create_commit(repo, {
        files = { ['versions.txt'] = 'v2' },
        message = 'Version 2',
      })

      local v2_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(v2_commit, 'V2 commit should exist')
      assert.is_not_equal(v1_commit, v2_commit, 'Commits should be different')

      local blob_v1 = GitBlob(repo, 'versions.txt', v1_commit)
      local content_v1, err1 = blob_v1:content()
      assert.is_nil(err1, 'Should not error reading v1 content')
      assert.is_not_nil(content_v1, 'V1 content should exist')
      assert.equals('v1', content_v1, 'V1 content should be "v1"')

      local blob_v2 = GitBlob(repo, 'versions.txt', 'HEAD')
      local content_v2, err2 = blob_v2:content()
      assert.is_nil(err2, 'Should not error reading v2 content')
      assert.is_not_nil(content_v2, 'V2 content should exist')
      assert.equals('v2', content_v2, 'V2 content should be "v2"')

      assert.is_not_equal(content_v1, content_v2, 'Content should be different between versions')
    end)

    it('returns error for nonexistent file', function()
      local blob = GitBlob(repo, 'nope.txt', 'HEAD')
      local content, err = blob:content()

      assert.is_nil(content, 'Content should be nil for nonexistent file')
      assert.is_not_nil(err, 'Should error for nonexistent file')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
    end)
  end)

  describe('lines', function()
    it('returns file content as array of lines', function()
      test_repo.create_commit(repo, {
        files = { ['lines.txt'] = { 'line 1', 'line 2', 'line 3' } },
        message = 'Add lines',
      })

      local blob = GitBlob(repo, 'lines.txt', 'HEAD')
      local lines, err = blob:lines()

      assert.is_nil(err, 'Should not error when reading lines')
      assert.is_table(lines, 'Lines should be a table')
      assert.equals(3, #lines, 'Should have exactly 3 lines')
      assert.equals('line 1', lines[1], 'First line should match')
      assert.equals('line 2', lines[2], 'Second line should match')
      assert.equals('line 3', lines[3], 'Third line should match')
    end)

    it('returns lines from specific commit', function()
      test_repo.create_commit(repo, {
        files = { ['history.txt'] = { 'old line 1', 'old line 2' } },
        message = 'Old version',
      })
      local old_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(old_commit, 'Old commit should exist')

      test_repo.create_commit(repo, {
        files = { ['history.txt'] = { 'new line 1', 'new line 2', 'new line 3' } },
        message = 'New version',
      })

      local blob_old = GitBlob(repo, 'history.txt', old_commit)
      local lines_old, err = blob_old:lines()
      assert.is_nil(err, 'Should not error when reading old lines')
      assert.is_table(lines_old, 'Old lines should be a table')
      assert.equals(2, #lines_old, 'Old version should have exactly 2 lines')
      assert.equals('old line 1', lines_old[1], 'Old first line should match')
      assert.equals('old line 2', lines_old[2], 'Old second line should match')

      local blob_new = GitBlob(repo, 'history.txt', 'HEAD')
      local lines_new, err2 = blob_new:lines()
      assert.is_nil(err2, 'Should not error when reading new lines')
      assert.is_table(lines_new, 'New lines should be a table')
      assert.equals(3, #lines_new, 'New version should have exactly 3 lines')
      assert.equals('new line 1', lines_new[1], 'New first line should match')
      assert.equals('new line 2', lines_new[2], 'New second line should match')
      assert.equals('new line 3', lines_new[3], 'New third line should match')
    end)

    it('returns error for nonexistent file', function()
      local blob = GitBlob(repo, 'nope.txt', 'HEAD')
      local lines, err = blob:lines()

      assert.is_nil(lines, 'Lines should be nil for nonexistent file')
      assert.is_not_nil(err, 'Should error for nonexistent file')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
    end)
  end)

  describe('size', function()
    it('returns size of file content', function()
      test_repo.create_commit(repo, {
        files = { ['sized.txt'] = 'hello' },
        message = 'Add sized',
      })

      local blob = GitBlob(repo, 'sized.txt', 'HEAD')
      local size, err = blob:size()

      assert.is_nil(err, 'Should not error when getting size')
      assert.is_not_nil(size, 'Size should not be nil')
      assert.is_number(size, 'Size should be a number')
      assert.equals(5, size, 'Size should be 5 bytes for "hello"')
    end)

    it('returns 0 for empty file', function()
      test_repo.create_commit(repo, {
        files = { ['empty.txt'] = '' },
        message = 'Add empty',
      })

      local blob = GitBlob(repo, 'empty.txt', 'HEAD')
      local size, err = blob:size()

      assert.is_nil(err, 'Should not error for empty file')
      assert.is_not_nil(size, 'Size should not be nil')
      assert.is_number(size, 'Size should be a number')
      assert.equals(0, size, 'Size should be exactly 0 for empty file')
    end)

    it('returns size from specific commit', function()
      test_repo.create_commit(repo, {
        files = { ['growing.txt'] = 'small' },
        message = 'Small version',
      })
      local small_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(small_commit, 'Small commit should exist')

      test_repo.create_commit(repo, {
        files = { ['growing.txt'] = 'much larger content here' },
        message = 'Large version',
      })

      local large_commit = test_repo.get_head_commit(repo)
      assert.is_not_equal(small_commit, large_commit, 'Commits should be different')

      local blob_small = GitBlob(repo, 'growing.txt', small_commit)
      local size_small, err = blob_small:size()
      assert.is_nil(err, 'Should not error getting small size')
      assert.is_not_nil(size_small, 'Small size should exist')
      assert.is_number(size_small, 'Small size should be a number')
      assert.equals(5, size_small, 'Size should be 5 for "small"')

      local blob_large = GitBlob(repo, 'growing.txt', 'HEAD')
      local size_large, err2 = blob_large:size()
      assert.is_nil(err2, 'Should not error getting large size')
      assert.is_not_nil(size_large, 'Large size should exist')
      assert.is_number(size_large, 'Large size should be a number')
      assert.equals(24, size_large, 'Size should be 24 for "much larger content here"')

      assert.is_true(size_large > size_small, 'Large file should be bigger than small file')
    end)

    it('returns error for nonexistent file', function()
      local blob = GitBlob(repo, 'nope.txt', 'HEAD')
      local size, err = blob:size()

      assert.is_nil(size, 'Size should be nil for nonexistent file')
      assert.is_not_nil(err, 'Should error for nonexistent file')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
    end)
  end)

  describe('hash', function()
    it('returns blob hash', function()
      test_repo.create_commit(repo, {
        files = { ['hashed.txt'] = 'content' },
        message = 'Add hashed',
      })

      local blob = GitBlob(repo, 'hashed.txt', 'HEAD')
      local hash, err = blob:hash()

      assert.is_nil(err, 'Should not error when getting hash')
      assert.is_not_nil(hash, 'Hash should not be nil')
      assert.is_string(hash, 'Hash should be a string')
      assert.equals(40, #hash, 'Hash should be 40 characters (full SHA-1)')
      assert.is_true(hash:match('^%x+$') ~= nil, 'Hash should be hexadecimal')
    end)

    it('returns same hash for same content', function()
      test_repo.create_commit(repo, {
        files = {
          ['file1.txt'] = 'same content',
          ['file2.txt'] = 'same content',
        },
        message = 'Add files',
      })

      local blob1 = GitBlob(repo, 'file1.txt', 'HEAD')
      local hash1, err1 = blob1:hash()

      local blob2 = GitBlob(repo, 'file2.txt', 'HEAD')
      local hash2, err2 = blob2:hash()

      assert.is_nil(err1, 'Should not error when getting hash1')
      assert.is_nil(err2, 'Should not error when getting hash2')
      assert.is_not_nil(hash1, 'Hash1 should exist')
      assert.is_not_nil(hash2, 'Hash2 should exist')
      assert.equals(hash1, hash2, 'Same content should produce same hash')
      assert.is_true(#hash1 == 40, 'Hash should be full SHA-1')
    end)

    it('returns different hash for different content', function()
      test_repo.create_commit(repo, {
        files = {
          ['file1.txt'] = 'content A',
          ['file2.txt'] = 'content B',
        },
        message = 'Add files',
      })

      local blob1 = GitBlob(repo, 'file1.txt', 'HEAD')
      local hash1, err1 = blob1:hash()

      local blob2 = GitBlob(repo, 'file2.txt', 'HEAD')
      local hash2, err2 = blob2:hash()

      assert.is_nil(err1, 'Should not error when getting hash1')
      assert.is_nil(err2, 'Should not error when getting hash2')
      assert.is_not_nil(hash1, 'Hash1 should exist')
      assert.is_not_nil(hash2, 'Hash2 should exist')
      assert.is_not_equal(hash1, hash2, 'Different content should produce different hashes')
      assert.equals(40, #hash1, 'Hash1 should be full SHA-1')
      assert.equals(40, #hash2, 'Hash2 should be full SHA-1')
    end)

    it('returns error for nonexistent file', function()
      local blob = GitBlob(repo, 'nope.txt', 'HEAD')
      local hash, err = blob:hash()

      assert.is_nil(hash, 'Hash should be nil for nonexistent file')
      assert.is_not_nil(err, 'Should error for nonexistent file')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
    end)
  end)

  describe('integration scenarios', function()
    it('handles file in subdirectory', function()
      test_repo.create_commit(repo, {
        files = { ['subdir/nested.txt'] = 'nested content' },
        message = 'Add nested',
      })

      local blob = GitBlob(repo, 'subdir/nested.txt', 'HEAD')
      local content, err = blob:content()

      assert.is_nil(err)
      assert.equals('nested content', content)
    end)

    it('compares blobs from different commits', function()
      test_repo.create_commit(repo, {
        files = { ['compare.txt'] = 'version 1' },
        message = 'V1',
      })
      local v1 = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['compare.txt'] = 'version 2' },
        message = 'V2',
      })
      local v2 = test_repo.get_head_commit(repo)

      local blob1 = GitBlob(repo, 'compare.txt', v1)
      local blob2 = GitBlob(repo, 'compare.txt', v2)

      local content1 = blob1:content()
      local content2 = blob2:content()

      assert.equals('version 1', content1)
      assert.equals('version 2', content2)
      assert.is_not_equal(content1, content2)
    end)

    it('works with relative commit refs', function()
      test_repo.create_commit(repo, {
        files = { ['relative.txt'] = 'old' },
        message = 'Old',
      })

      test_repo.create_commit(repo, {
        files = { ['relative.txt'] = 'new' },
        message = 'New',
      })

      local blob_old = GitBlob(repo, 'relative.txt', 'HEAD~1')
      local content_old, err = blob_old:content()

      assert.is_nil(err)
      assert.equals('old', content_old)
    end)
  end)
end)
