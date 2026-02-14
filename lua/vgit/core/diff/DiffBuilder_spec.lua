local DiffBuilder = require('vgit.core.diff.DiffBuilder')
local fs = require('vgit.core.fs')

local eq = assert.are.same

describe('DiffBuilder:', function()
  local repository
  local builder
  local original_absolute_path
  local original_read_file

  before_each(function()
    original_absolute_path = fs.absolute_path
    original_read_file = fs.read_file

    fs.absolute_path = function(repo_path, filename)
      return repo_path .. '/' .. filename
    end

    fs.read_file = function(path)
      return { 'working tree line 1', 'working tree line 2', 'working tree line 3' }
    end

    repository = {
      _path = '/test/repo',
      get_path = function(self)
        return self._path
      end,
      file_lines = function(self, filename, ref)
        if ref == 'HEAD' then
          return { 'line 1', 'line 2', 'line 3' }
        elseif ref == 'index' then
          return { 'line 1', 'line 2', 'line 3 modified' }
        elseif ref == 'HEAD~1' then
          return { 'old line 1', 'old line 2' }
        elseif ref == 'HEAD~2' then
          return { 'ancient line 1' }
        elseif ref == 'v1.0' then
          return { 'v1.0 line 1', 'v1.0 line 2' }
        elseif ref == 'v2.0' then
          return { 'v2.0 line 1', 'v2.0 line 2', 'v2.0 line 3' }
        elseif ref == 'main' then
          return { 'main line 1', 'main line 2' }
        elseif ref == 'feature' then
          return { 'feature line 1', 'feature line 2', 'feature line 3', 'feature line 4' }
        else
          return { 'commit lines for ' .. ref }
        end
      end,
    }

    builder = DiffBuilder(repository)
  end)

  after_each(function()
    fs.absolute_path = original_absolute_path
    fs.read_file = original_read_file
  end)

  describe('constructor', function()
    it('should initialize with a repository', function()
      assert.are.equal(builder._repository, repository)
    end)

    it('should store repository reference for later use', function()
      assert.is_not_nil(builder._repository)
      assert.are.equal(builder._repository:get_path(), '/test/repo')
    end)
  end)

  describe('_get_range_lines with working_tree to', function()
    it('should get unstaged lines from filesystem vs index', function()
      local spec = {
        filename = 'test.lua',
        from = 'index',
        to = 'disk',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
      assert.are.equal(original[1], 'line 1')
      assert.are.equal(original[3], 'line 3 modified')
      assert.are.equal(current[3], 'working tree line 3')
    end)

    it('should get all changes from filesystem vs HEAD', function()
      local spec = {
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
      assert.are.equal(original[1], 'line 1')
      assert.are.equal(current[1], 'working tree line 1')
    end)

    it('should compute correct path when reading from filesystem', function()
      local called_with_path = nil
      fs.read_file = function(path)
        called_with_path = path
        return { 'content' }
      end

      local spec = {
        filename = 'src/main.lua',
        from = 'HEAD',
        to = 'disk',
      }

      builder:_get_range_lines(spec)

      assert.is_not_nil(called_with_path)
      assert.are.equal(called_with_path, '/test/repo/src/main.lua')
    end)

    it('should handle deeply nested file paths', function()
      local spec = {
        filename = 'src/components/deep/nested/file.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)
  end)

  describe('_get_blame_lines', function()
    it('should get blame lines for a commit', function()
      local spec = {
        filename = 'test.lua',
        blame_commit = 'abc123',
      }

      local original, current = builder:_get_blame_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should use custom parent commit if provided', function()
      local spec = {
        filename = 'test.lua',
        blame_commit = 'abc123',
        parent_commit = 'abc123~2',
      }

      local original, current = builder:_get_blame_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should require blame_commit field', function()
      local spec = {
        filename = 'test.lua',
      }

      assert.has_error(function()
        builder:_get_blame_lines(spec)
      end)
    end)

    it('should compute parent commit correctly', function()
      local spec = {
        filename = 'test.lua',
        blame_commit = 'abc123def456',
      }

      local original, current = builder:_get_blame_lines(spec)

      assert.is_not_nil(original)
    end)

    it('should handle long commit hashes', function()
      local spec = {
        filename = 'test.lua',
        blame_commit = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b',
      }

      local original, current = builder:_get_blame_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should handle short commit hashes', function()
      local spec = {
        filename = 'test.lua',
        blame_commit = 'abc123',
      }

      local original, current = builder:_get_blame_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)
  end)

  describe('_get_range_lines', function()
    it('should use default range HEAD~1 to HEAD', function()
      local spec = {
        filename = 'test.lua',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
      assert.are.equal(original[1], 'old line 1')
      assert.are.equal(current[1], 'line 1')
    end)

    it('should use custom start and end refs', function()
      local spec = {
        filename = 'test.lua',
        from = 'main',
        to = 'feature',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
      assert.are.equal(original[1], 'main line 1')
      assert.are.equal(current[1], 'feature line 1')
    end)

    it('should use only from when to not provided', function()
      local spec = {
        filename = 'test.lua',
        from = 'main',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should use only to when from not provided', function()
      local spec = {
        filename = 'test.lua',
        to = 'feature',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should support comparing version tags', function()
      local spec = {
        filename = 'test.lua',
        from = 'v1.0',
        to = 'v2.0',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.are.equal(#original, 2)
      assert.are.equal(#current, 3)
    end)

    it('should support arbitrary ref names', function()
      local spec = {
        filename = 'test.lua',
        from = 'refs/heads/main',
        to = 'refs/heads/develop',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should support multi-level history navigation', function()
      local spec = {
        filename = 'test.lua',
        from = 'HEAD~2',
        to = 'HEAD',
      }

      local original, current = builder:_get_range_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
      assert.are.equal(original[1], 'ancient line 1')
    end)

    it('should use old_filename for the from side when provided', function()
      local called_filenames = {}
      local original_file_lines = repository.file_lines
      repository.file_lines = function(self, filename, ref)
        called_filenames[#called_filenames + 1] = { filename = filename, ref = ref }
        return original_file_lines(self, filename, ref)
      end

      local spec = {
        filename = 'new_name.lua',
        old_filename = 'old_name.lua',
        from = 'HEAD',
        to = 'index',
      }

      builder:_get_range_lines(spec)

      -- The from side should use old_filename
      assert.are.equal(called_filenames[1].filename, 'old_name.lua')
      assert.are.equal(called_filenames[1].ref, 'HEAD')
      -- The to side should use filename
      assert.are.equal(called_filenames[2].filename, 'new_name.lua')
      assert.are.equal(called_filenames[2].ref, 'index')
    end)

    it('should use filename for the from side when old_filename is nil', function()
      local called_filenames = {}
      local original_file_lines = repository.file_lines
      repository.file_lines = function(self, filename, ref)
        called_filenames[#called_filenames + 1] = { filename = filename, ref = ref }
        return original_file_lines(self, filename, ref)
      end

      local spec = {
        filename = 'test.lua',
        from = 'HEAD',
        to = 'index',
      }

      builder:_get_range_lines(spec)

      -- Both sides should use filename
      assert.are.equal(called_filenames[1].filename, 'test.lua')
      assert.are.equal(called_filenames[2].filename, 'test.lua')
    end)
  end)

  describe('_get_conflict_lines', function()
    it('should read conflict lines from filesystem', function()
      fs.read_file = function()
        return {
          '<<<<<<< HEAD',
          'our changes',
          '=======',
          'their changes',
          '>>>>>>> branch',
        }
      end

      local spec = {
        filename = 'test.lua',
      }

      local original, current = builder:_get_conflict_lines(spec)

      assert.is_nil(original)
      assert.is_not_nil(current)
      assert.are.equal(#current, 5)
      assert.are.equal(current[1], '<<<<<<< HEAD')
      assert.are.equal(current[5], '>>>>>>> branch')
    end)

    it('should fail if file cannot be read', function()
      fs.read_file = function(path)
        return nil
      end

      local spec = {
        filename = 'test.lua',
      }

      assert.has_error(function()
        builder:_get_conflict_lines(spec)
      end)
    end)

    it('should handle empty conflict file', function()
      fs.read_file = function(path)
        return {}
      end

      local spec = {
        filename = 'test.lua',
      }

      local original, current = builder:_get_conflict_lines(spec)

      assert.is_nil(original)
      assert.is_not_nil(current)
      assert.are.equal(#current, 0)
    end)

    it('should handle multiple conflict sections', function()
      fs.read_file = function(path)
        return {
          '<<<<<<< HEAD',
          'conflict 1 ours',
          '=======',
          'conflict 1 theirs',
          '>>>>>>> branch',
          'neutral content',
          '<<<<<<< HEAD',
          'conflict 2 ours',
          '=======',
          'conflict 2 theirs',
          '>>>>>>> branch',
        }
      end

      local spec = {
        filename = 'test.lua',
      }

      local original, current = builder:_get_conflict_lines(spec)

      assert.is_not_nil(current)
      assert.are.equal(#current, 11)
    end)

    it('should compute correct path for deeply nested files', function()
      local called_with_path = nil
      fs.read_file = function(path)
        called_with_path = path
        return { '<<<<<<< HEAD', '=======', '>>>>>>> branch' }
      end

      local spec = {
        filename = 'src/deeply/nested/file.lua',
      }

      builder:_get_conflict_lines(spec)

      assert.is_not_nil(called_with_path)
      assert.are.equal(called_with_path, '/test/repo/src/deeply/nested/file.lua')
    end)

    it('should handle files with special characters in names', function()
      fs.read_file = function(path)
        return { 'content' }
      end

      local spec = {
        filename = 'test-file_with.special-chars.lua',
      }

      local original, current = builder:_get_conflict_lines(spec)

      assert.is_not_nil(current)
    end)
  end)

  describe('_get_lines', function()
    it('should dispatch to correct handler for range type (unstaged changes)', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local original, current = builder:_get_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should dispatch to correct handler for range type (staged changes)', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'index',
        to = 'disk',
      }

      local original, current = builder:_get_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should dispatch to correct handler for range type (commits)', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD~1',
        to = 'HEAD',
      }

      local original, current = builder:_get_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should dispatch to correct handler for blame type', function()
      local spec = {
        type = 'blame',
        filename = 'test.lua',
        blame_commit = 'abc123',
      }

      local original, current = builder:_get_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should dispatch to correct handler for range type with defaults', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
      }

      local original, current = builder:_get_lines(spec)

      assert.is_not_nil(original)
      assert.is_not_nil(current)
    end)

    it('should dispatch to correct handler for conflict type', function()
      fs.read_file = function(path)
        return { '<<<<<<< HEAD', 'content', '=======' }
      end

      local spec = {
        type = 'conflict',
        filename = 'test.lua',
      }

      local original, current = builder:_get_lines(spec)

      assert.is_nil(original)
      assert.is_not_nil(current)
    end)

    it('should require spec', function()
      assert.has_error(function()
        builder:_get_lines(nil)
      end)
    end)

    it('should require spec.type', function()
      assert.has_error(function()
        builder:_get_lines({ filename = 'test.lua' })
      end)
    end)

    it('should require spec.filename', function()
      assert.has_error(function()
        builder:_get_lines({ type = 'range' })
      end)
    end)

    it('should require spec.blame_commit for blame type', function()
      assert.has_error(function()
        builder:_get_lines({ type = 'blame', filename = 'test.lua' })
      end)
    end)

    it('should fail for unknown diff type', function()
      assert.has_error(function()
        builder:_get_lines({ type = 'unknown', filename = 'test.lua' })
      end)
    end)
  end)

  describe('_get_metadata', function()
    it('should generate range metadata for unstaged changes', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'range')
      assert.are.equal(metadata.filename, 'test.lua')
      assert.are.equal(metadata.from, 'HEAD')
      assert.are.equal(metadata.to, 'disk')
    end)

    it('should generate range metadata for staged changes', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'index',
        to = 'disk',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'range')
      assert.are.equal(metadata.from, 'index')
      assert.are.equal(metadata.to, 'disk')
    end)

    it('should generate range metadata with defaults', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'range')
      assert.are.equal(metadata.from, 'HEAD~1')
      assert.are.equal(metadata.to, 'HEAD')
      assert.are.equal(metadata.filename, 'test.lua')
    end)

    it('should generate range metadata with custom refs', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'v1.0',
        to = 'v2.0',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'range')
      assert.are.equal(metadata.from, 'v1.0')
      assert.are.equal(metadata.to, 'v2.0')
    end)

    it('should generate blame metadata', function()
      local spec = {
        type = 'blame',
        filename = 'test.lua',
        blame_commit = 'abc123',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'blame')
      assert.are.equal(metadata.blamed_commit, 'abc123')
      assert.are.equal(metadata.current_ref, 'abc123')
      assert.are.equal(metadata.filename, 'test.lua')
    end)

    it('should generate blame metadata with custom parent', function()
      local spec = {
        type = 'blame',
        filename = 'test.lua',
        blame_commit = 'abc123',
        parent_commit = 'xyz789',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'blame')
      assert.are.equal(metadata.base_ref, 'xyz789')
    end)

    it('should generate range metadata with branch comparison', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'main',
        to = 'feature',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'range')
      assert.are.equal(metadata.from, 'main')
      assert.are.equal(metadata.to, 'feature')
    end)

    it('should generate conflict metadata', function()
      local spec = {
        type = 'conflict',
        filename = 'test.lua',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.comparison_mode, 'conflict')
      assert.are.equal(metadata.filename, 'test.lua')
      assert.is_true(metadata.is_unmerged)
    end)

    it('should return empty metadata for unknown type', function()
      local spec = {
        type = 'unknown',
        filename = 'test.lua',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(vim.tbl_count(metadata), 0)
    end)

    it('should preserve all metadata fields', function()
      local spec = {
        type = 'range',
        filename = 'src/main.lua',
        from = 'v1.0',
        to = 'v2.0',
      }

      local metadata = builder:_get_metadata(spec)

      assert.is_not_nil(metadata.comparison_mode)
      assert.is_not_nil(metadata.from)
      assert.is_not_nil(metadata.to)
      assert.is_not_nil(metadata.filename)
    end)

    it('should handle deeply nested filenames in metadata', function()
      local spec = {
        type = 'range',
        filename = 'src/very/deeply/nested/file.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local metadata = builder:_get_metadata(spec)

      assert.are.equal(metadata.filename, 'src/very/deeply/nested/file.lua')
    end)
  end)

  describe('build', function()
    it('should require spec', function()
      assert.has_error(function()
        builder:build(nil)
      end)
    end)

    it('should require spec.type', function()
      assert.has_error(function()
        builder:build({ filename = 'test.lua' })
      end)
    end)

    it('should build range diff for unstaged changes', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.lines)
      assert.is_not_nil(diff.hunks)
      assert.is_not_nil(diff.lnum_changes)
      assert.is_not_nil(diff.marks)
      assert.is_not_nil(diff.stat)
    end)

    it('should build range diff for staged changes', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'index',
        to = 'disk',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.hunks)
    end)

    it('should build range diff with defaults', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.hunks)
    end)

    it('should build range diff with custom refs', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'v1.0',
        to = 'v2.0',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.hunks)
    end)

    it('should build blame diff', function()
      local spec = {
        type = 'blame',
        filename = 'test.lua',
        blame_commit = 'abc123',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.hunks)
    end)

    it('should build blame diff with custom parent', function()
      local spec = {
        type = 'blame',
        filename = 'test.lua',
        blame_commit = 'abc123',
        parent_commit = 'parent123',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.hunks)
    end)

    it('should build range diff with branch comparison', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'main',
        to = 'feature',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.hunks)
    end)

    it('should build conflict diff', function()
      fs.read_file = function(path)
        return {
          '<<<<<<< HEAD',
          'our changes',
          '=======',
          'their changes',
          '>>>>>>> branch',
        }
      end

      local spec = {
        type = 'conflict',
        filename = 'test.lua',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.marks)
    end)

    it('should produce unified diff with display lines', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
        layout_type = 'unified',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.lines)
      assert.is_true(#diff.lines > 0)
    end)

    it('should produce split diff with equal-length current_lines and previous_lines', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.current_lines)
      assert.is_not_nil(diff.previous_lines)
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
    end)

    it('should produce split diff with equal-length lines for staged changes', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'index',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
    end)

    it('should produce split diff with equal-length lines for branch comparison', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'main',
        to = 'feature',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
    end)

    it('should produce split diff with equal-length lines for version tags', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'v1.0',
        to = 'v2.0',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
    end)

    it('should not place raw source lines on the diff object', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      -- DiffBuilder should not attach raw source lines to the diff.
      -- current_lines/previous_lines are split-aligned display lines set by Diff:generate_split.
      -- Raw source lines are the concern of the caller, not the diff object.
      assert.is_not_nil(diff.current_lines)
      assert.is_not_nil(diff.previous_lines)
      -- Verify they are the split-aligned versions (equal length), not raw source
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
    end)

    it('should support all valid layout types', function()
      local layout_types = { 'unified', 'split' }

      for _, layout_type in ipairs(layout_types) do
        local spec = {
          type = 'range',
          filename = 'test.lua',
          from = 'HEAD',
          to = 'disk',
          layout_type = layout_type,
        }

        local diff = builder:build(spec)
        assert.is_not_nil(diff)
        assert.is_not_nil(diff.hunks)
      end
    end)

    it('should fail with unknown layout type', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
        layout_type = 'invalid_layout',
      }

      assert.has_error(function()
        builder:build(spec)
      end)
    end)

    it('should handle deeply nested file paths', function()
      local spec = {
        type = 'range',
        filename = 'src/components/helpers/utils/deep/file.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
    end)

    it('should handle files with special characters', function()
      local spec = {
        type = 'range',
        filename = 'test-file_with.special-chars.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
    end)

    it('should not mutate spec table', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
      }

      local spec_copy = vim.tbl_deep_extend('force', {}, spec)

      builder:build(spec)

      eq(spec, spec_copy)
    end)
  end)

  describe('integration scenarios', function()
    it('should handle complete workflow for unstaged changes (unified)', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
        layout_type = 'unified',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.lines)
      assert.is_true(#diff.lines > 0)
      assert.is_not_nil(diff.hunks)
    end)

    it('should handle complete workflow for staged changes (split)', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'index',
        to = 'disk',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
      assert.is_not_nil(diff.hunks)
    end)

    it('should handle version comparison workflow', function()
      local spec = {
        type = 'range',
        filename = 'src/api.lua',
        from = 'v1.0.0',
        to = 'v2.0.0',
        layout_type = 'unified',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.lines)
    end)

    it('should handle blame investigation workflow', function()
      local spec = {
        type = 'blame',
        filename = 'src/core.lua',
        blame_commit = 'abc123def456',
        parent_commit = 'parent123',
        layout_type = 'unified',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.lines)
    end)

    it('should handle branch comparison workflow (split)', function()
      local spec = {
        type = 'range',
        filename = 'src/main.lua',
        from = 'main',
        to = 'develop',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
    end)

    it('should handle conflict resolution workflow', function()
      fs.read_file = function(path)
        return {
          'normal line 1',
          '<<<<<<< HEAD',
          'our version',
          '=======',
          'their version',
          '>>>>>>> feature',
          'normal line 2',
        }
      end

      local spec = {
        type = 'conflict',
        filename = 'src/conflict.lua',
        layout_type = 'unified',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.is_not_nil(diff.marks)
    end)

    it('should handle split conflict resolution workflow', function()
      fs.read_file = function(path)
        return {
          'normal line 1',
          '<<<<<<< HEAD',
          'our version',
          '=======',
          'their version',
          '>>>>>>> feature',
          'normal line 2',
        }
      end

      local spec = {
        type = 'conflict',
        filename = 'src/conflict.lua',
        layout_type = 'split',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
      assert.are.equal(#diff.current_lines, #diff.previous_lines)
    end)
  end)

  describe('error handling and edge cases', function()
    it('should handle repository returning nil for file_lines', function()
      repository.file_lines = function(self, filename, ref)
        return nil
      end

      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'index',
        to = 'disk',
      }

      -- Should handle gracefully by treating nil as empty
      local diff = builder:build(spec)
      assert.is_not_nil(diff)
    end)

    it('should handle repository returning empty file', function()
      repository.file_lines = function(self, filename, ref)
        return {}
      end

      local spec = {
        type = 'range',
        filename = 'test.lua',
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
    end)

    it('should handle gracefully when fs.read_file fails', function()
      fs.read_file = function(path)
        return nil
      end

      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
      }

      -- Should handle gracefully by treating nil as empty
      local diff = builder:build(spec)
      assert.is_not_nil(diff)
    end)

    it('should handle spec with extra unknown fields', function()
      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
        unknown_field = 'should be ignored',
        another_field = 123,
      }

      local diff = builder:build(spec)

      assert.is_not_nil(diff)
    end)

    it('should handle all diff types with same repository', function()
      local types = { 'range', 'blame', 'conflict' }

      for _, diff_type in ipairs(types) do
        local spec = {
          type = diff_type,
          filename = 'test.lua',
          from = 'HEAD',
          to = 'disk',
          blame_commit = 'abc123',
        }

        if diff_type == 'conflict' then
          fs.read_file = function(path)
            return { '<<<<<<< HEAD', '=======', '>>>>>>> branch' }
          end
        end

        local diff = builder:build(spec)
        assert.is_not_nil(diff)
      end
    end)

    it('should handle rapid sequential builds', function()
      for i = 1, 10 do
        local spec = {
          type = 'range',
          filename = 'test' .. i .. '.lua',
          from = 'HEAD',
          to = 'disk',
        }

        local diff = builder:build(spec)
        assert.is_not_nil(diff)
      end
    end)

    it('should handle different filename patterns', function()
      local filenames = {
        'simple.lua',
        'with-dashes.lua',
        'with_underscores.lua',
        'with123numbers.lua',
        'src/path/to/file.lua',
        'deeply/nested/path/to/some/deep/file.lua',
      }

      for _, filename in ipairs(filenames) do
        local spec = {
          type = 'range',
          filename = filename,
        }

        local diff = builder:build(spec)
        assert.is_not_nil(diff)
      end
    end)
  end)

  describe('repository interaction validation', function()
    it('should call repository.get_path for unstaged working tree', function()
      local get_path_called = false
      repository.get_path = function(self)
        get_path_called = true
        return '/test/repo'
      end

      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'HEAD',
        to = 'disk',
      }

      builder:build(spec)

      assert.is_true(get_path_called)
    end)

    it('should call repository.file_lines for staged working tree', function()
      local file_lines_called = false
      local original_file_lines = repository.file_lines
      repository.file_lines = function(self, filename, ref)
        file_lines_called = true
        return original_file_lines(self, filename, ref)
      end

      local spec = {
        type = 'range',
        filename = 'test.lua',
        from = 'index',
        to = 'disk',
      }

      builder:build(spec)

      assert.is_true(file_lines_called)
    end)

    it('should call repository.file_lines for each diff type', function()
      local call_counts = {}

      local original_file_lines = repository.file_lines
      repository.file_lines = function(self, filename, ref)
        call_counts[ref] = (call_counts[ref] or 0) + 1
        return original_file_lines(self, filename, ref)
      end

      local specs = {
        { type = 'range', filename = 'test.lua' },
        { type = 'blame', filename = 'test.lua', blame_commit = 'abc' },
        { type = 'range', filename = 'test.lua', from = 'v1.0', to = 'v2.0' },
      }

      for _, spec in ipairs(specs) do
        builder:build(spec)
      end

      -- Should have called file_lines multiple times
      assert.is_true(vim.tbl_count(call_counts) > 0)
    end)
  end)
end)
