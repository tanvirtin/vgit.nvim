local GitPatch = require('vgit.git.GitPatch')
local GitHunk = require('vgit.git.GitHunk')

local eq = assert.are.same

describe('GitPatch:', function()
  describe('constructor', function()
    it('should generate complete patch with all required headers', function()
      local hunk = GitHunk('@@ -10,5 +10,5 @@ context')
      hunk.diff = { '-old line', '+new line' }

      local patch = GitPatch('test.lua', hunk)

      -- Verify it's a proper patch array with minimum required lines
      assert.is_table(patch)
      assert.is_true(#patch >= 5, 'patch should have at least 5 lines (headers + hunk + diff)')

      -- Verify essential patch structure
      assert.is_truthy(patch[1]:match('^diff %-%-git'), 'first line should be diff header')
      assert.is_truthy(patch[2]:match('^index'), 'second line should be index')
      assert.is_truthy(patch[5]:match('^@@'), 'should contain hunk header')
    end)

    it('should include diff --git header', function()
      local hunk = GitHunk('@@ -10,5 +10,5 @@ context')
      hunk.diff = { '-old', '+new' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[1], 'diff --git a/test.lua b/test.lua')
    end)

    it('should include index line', function()
      local hunk = GitHunk('@@ -10,5 +10,5 @@ context')
      hunk.diff = { '-old', '+new' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[2], 'index 000000..000000')
    end)

    it('should include file markers', function()
      local hunk = GitHunk('@@ -10,5 +10,5 @@ context')
      hunk.diff = { '-old', '+new' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[3], '--- a/test.lua')
      eq(patch[4], '+++ a/test.lua')
    end)

    it('should include hunk header', function()
      local hunk = GitHunk('@@ -10,5 +10,5 @@ context')
      hunk.diff = { '-old', '+new' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[5], '@@ -10,5 +10,5 @@ context')
    end)

    it('should include diff lines', function()
      local hunk = GitHunk('@@ -10,5 +10,5 @@ context')
      hunk.diff = { '-old line', '+new line' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[6], '-old line')
      eq(patch[7], '+new line')
    end)

    it('should generate correct patch structure for change type', function()
      local hunk = GitHunk('@@ -10,3 +10,3 @@ context')
      hunk.diff = { '-line1', '-line2', '+line3', '+line4' }

      local patch = GitPatch('file.txt', hunk)

      eq(#patch, 9) -- 5 header lines + 4 diff lines
      eq(patch[1], 'diff --git a/file.txt b/file.txt')
      eq(patch[2], 'index 000000..000000')
      eq(patch[3], '--- a/file.txt')
      eq(patch[4], '+++ a/file.txt')
      eq(patch[5], '@@ -10,3 +10,3 @@ context')
      eq(patch[6], '-line1')
      eq(patch[7], '-line2')
      eq(patch[8], '+line3')
      eq(patch[9], '+line4')
    end)

    it('should handle add type hunk with modified header', function()
      local hunk = GitHunk('@@ -17,0 +18,15 @@ context')
      hunk.type = 'add'
      hunk.diff = { '+new line 1', '+new line 2', '+new line 3' }

      local patch = GitPatch('test.lua', hunk)

      -- For add type, header should be recalculated
      assert.is_true(patch[5]:match('^@@ ') ~= nil)
      eq(patch[6], '+new line 1')
      eq(patch[7], '+new line 2')
      eq(patch[8], '+new line 3')
    end)

    it('should handle remove type hunk', function()
      local hunk = GitHunk('@@ -10,3 +10,0 @@ context')
      hunk.type = 'remove'
      hunk.diff = { '-removed line 1', '-removed line 2' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[5], '@@ -10,3 +10,0 @@ context')
      eq(patch[6], '-removed line 1')
      eq(patch[7], '-removed line 2')
    end)

    it('should handle hunk with no diff lines', function()
      local hunk = GitHunk('@@ -10,0 +10,0 @@ context')
      hunk.diff = {}

      local patch = GitPatch('test.lua', hunk)

      eq(#patch, 5) -- Only header lines, no diff lines
    end)

    it('should work with different file paths', function()
      local hunk = GitHunk('@@ -1,1 +1,1 @@')
      hunk.diff = { '-old', '+new' }

      local patch1 = GitPatch('dir/subdir/file.lua', hunk)
      local patch2 = GitPatch('file-with-dash.txt', hunk)
      local patch3 = GitPatch('file_with_underscore.py', hunk)

      eq(patch1[1], 'diff --git a/dir/subdir/file.lua b/dir/subdir/file.lua')
      eq(patch2[1], 'diff --git a/file-with-dash.txt b/file-with-dash.txt')
      eq(patch3[1], 'diff --git a/file_with_underscore.py b/file_with_underscore.py')
    end)

    it('should handle multiple context lines in diff', function()
      local hunk = GitHunk('@@ -5,5 +5,5 @@ context')
      hunk.diff = { ' context1', '-old', '+new', ' context2' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[6], ' context1')
      eq(patch[7], '-old')
      eq(patch[8], '+new')
      eq(patch[9], ' context2')
    end)

    it('should handle diff with empty lines', function()
      local hunk = GitHunk('@@ -5,3 +5,3 @@')
      hunk.diff = { '-', '+new line', ' ' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[6], '-')
      eq(patch[7], '+new line')
      eq(patch[8], ' ')
    end)
  end)

  describe('edge cases', function()
    it('should handle file paths with spaces', function()
      local hunk = GitHunk('@@ -1,1 +1,1 @@')
      hunk.diff = { '-old', '+new' }

      local patch = GitPatch('path with spaces.lua', hunk)

      eq(patch[1], 'diff --git a/path with spaces.lua b/path with spaces.lua')
      eq(patch[3], '--- a/path with spaces.lua')
      eq(patch[4], '+++ a/path with spaces.lua')
    end)

    it('should handle file paths with special characters', function()
      local hunk = GitHunk('@@ -1,1 +1,1 @@')
      hunk.diff = { '-old', '+new' }

      local patch = GitPatch('file-name_test.lua', hunk)

      eq(patch[1], 'diff --git a/file-name_test.lua b/file-name_test.lua')
    end)

    it('should handle very large diff', function()
      local hunk = GitHunk('@@ -1,100 +1,100 @@')
      hunk.diff = {}
      for i = 1, 100 do
        hunk.diff[#hunk.diff + 1] = '-line ' .. i
        hunk.diff[#hunk.diff + 1] = '+new line ' .. i
      end

      local patch = GitPatch('test.lua', hunk)

      eq(#patch, 205) -- 5 header + 200 diff lines
    end)

    it('should handle hunk with special characters in diff', function()
      local hunk = GitHunk('@@ -1,1 +1,1 @@')
      hunk.diff = { '-line with "quotes"', '+line with \'quotes\'' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[6], '-line with "quotes"')
      eq(patch[7], '+line with \'quotes\'')
    end)
  end)

  describe('add type special handling', function()
    it('should recalculate header for add type', function()
      local hunk = GitHunk('@@ -10,0 +11,5 @@')
      hunk.type = 'add'
      hunk.diff = { '+line1', '+line2', '+line3', '+line4', '+line5' }

      local patch = GitPatch('test.lua', hunk)

      -- The header should be recalculated for add type
      local header = patch[5]
      assert.is_true(header:match('^@@ ') ~= nil)
      -- Should contain the number of diff lines (5)
      assert.is_true(header:match(',5 @@') ~= nil)
    end)

    it('should use original header for non-add types', function()
      local original_header = '@@ -10,5 +10,5 @@ context line'
      local hunk = GitHunk(original_header)
      hunk.type = 'change'
      hunk.diff = { '-old', '+new' }

      local patch = GitPatch('test.lua', hunk)

      eq(patch[5], original_header)
    end)
  end)
end)
