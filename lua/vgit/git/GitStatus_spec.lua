local GitStatus = require('vgit.git.GitStatus')

local eq = assert.are.same

describe('GitStatus:', function()
  describe('constructor', function()
    it('should parse status string with filename', function()
      local status = GitStatus(' M test.lua')

      eq(status.value, ' M')
      eq(status.first, ' ')
      eq(status.second, 'M')
      eq(status.filename, 'test.lua')
    end)

    it('should parse staged modification', function()
      local status = GitStatus('M  file.txt')

      eq(status.first, 'M')
      eq(status.second, ' ')
      eq(status.filename, 'file.txt')
    end)

    it('should parse untracked file', function()
      local status = GitStatus('?? newfile.lua')

      eq(status.value, '??')
      eq(status.first, '?')
      eq(status.second, '?')
      eq(status.filename, 'newfile.lua')
    end)

    it('should remove quotes from filename', function()
      local status = GitStatus('A  "quoted file.txt"')

      eq(status.filename, 'quoted file.txt')
    end)

    it('should detect filetype from filename', function()
      local status = GitStatus('M  test.lua')

      eq(status.filetype, 'lua')
    end)

    it('should parse deleted file', function()
      local status = GitStatus(' D deleted.lua')

      eq(status.first, ' ')
      eq(status.second, 'D')
      eq(status.filename, 'deleted.lua')
    end)

    it('should parse added file', function()
      local status = GitStatus('A  added.lua')

      eq(status.first, 'A')
      eq(status.second, ' ')
      eq(status.filename, 'added.lua')
    end)

    it('should parse renamed file', function()
      local status = GitStatus('R  renamed.lua')

      eq(status.first, 'R')
      eq(status.second, ' ')
      eq(status.filename, 'renamed.lua')
    end)

    it('should parse merge conflict', function()
      local status = GitStatus('UU conflict.lua')

      eq(status.first, 'U')
      eq(status.second, 'U')
      eq(status.filename, 'conflict.lua')
    end)
  end)

  describe('parse', function()
    it('should split two-character status into first and second', function()
      local status = GitStatus(' M test.lua')
      local first, second = status:parse('AM')

      eq(first, 'A')
      eq(second, 'M')
    end)

    it('should handle space characters', function()
      local status = GitStatus(' M test.lua')
      local first, second = status:parse(' M')

      eq(first, ' ')
      eq(second, 'M')
    end)
  end)

  describe('has', function()
    it('should return true for exact match', function()
      local status = GitStatus('AM file.lua')

      assert.is_true(status:has('AM'))
    end)

    it('should return false for non-match', function()
      local status = GitStatus('AM file.lua')

      assert.is_false(status:has('MM'))
    end)

    it('should match with wildcard in first position', function()
      local status = GitStatus('AM file.lua')

      assert.is_true(status:has('*M'))
    end)

    it('should match with wildcard in second position', function()
      local status = GitStatus('AM file.lua')

      assert.is_true(status:has('A*'))
    end)

    it('should not match if wildcard second position does not match', function()
      local status = GitStatus('AM file.lua')

      assert.is_false(status:has('M*'))
    end)

    it('should not match if wildcard first position does not match', function()
      local status = GitStatus('AM file.lua')

      assert.is_false(status:has('*A'))
    end)
  end)

  describe('has_either', function()
    it('should return true if first matches', function()
      local status = GitStatus('AM file.lua')

      assert.is_true(status:has_either('AD'))
    end)

    it('should return true if second matches', function()
      local status = GitStatus('AM file.lua')

      assert.is_true(status:has_either('DM'))
    end)

    it('should return true if both match', function()
      local status = GitStatus('AM file.lua')

      assert.is_true(status:has_either('AM'))
    end)

    it('should return false if neither matches', function()
      local status = GitStatus('AM file.lua')

      assert.is_false(status:has_either('DD'))
    end)
  end)

  describe('has_both', function()
    it('should return true if both positions match', function()
      local status = GitStatus('AM file.lua')

      assert.is_true(status:has_both('AM'))
    end)

    it('should return false if only first matches', function()
      local status = GitStatus('AM file.lua')

      assert.is_false(status:has_both('AD'))
    end)

    it('should return false if only second matches', function()
      local status = GitStatus('AM file.lua')

      assert.is_false(status:has_both('DM'))
    end)

    it('should return false if neither matches', function()
      local status = GitStatus('AM file.lua')

      assert.is_false(status:has_both('DD'))
    end)
  end)

  describe('is_unmerged', function()
    it('should return true for DD status', function()
      local status = GitStatus('DD conflict.lua')
      assert.is_true(status:is_unmerged())
    end)

    it('should return true for AU status', function()
      local status = GitStatus('AU conflict.lua')
      assert.is_true(status:is_unmerged())
    end)

    it('should return true for UD status', function()
      local status = GitStatus('UD conflict.lua')
      assert.is_true(status:is_unmerged())
    end)

    it('should return true for UA status', function()
      local status = GitStatus('UA conflict.lua')
      assert.is_true(status:is_unmerged())
    end)

    it('should return true for DU status', function()
      local status = GitStatus('DU conflict.lua')
      assert.is_true(status:is_unmerged())
    end)

    it('should return true for AA status', function()
      local status = GitStatus('AA conflict.lua')
      assert.is_true(status:is_unmerged())
    end)

    it('should return true for UU status', function()
      local status = GitStatus('UU conflict.lua')
      assert.is_true(status:is_unmerged())
    end)

    it('should return false for normal modification', function()
      local status = GitStatus(' M file.lua')
      assert.is_false(status:is_unmerged())
    end)

    it('should return false for added file', function()
      local status = GitStatus('A  file.lua')
      assert.is_false(status:is_unmerged())
    end)
  end)

  describe('is_staged', function()
    it('should return true for staged added file', function()
      local status = GitStatus('A  file.lua')
      assert.is_true(status:is_staged())
    end)

    it('should return true for staged modified file', function()
      local status = GitStatus('M  file.lua')
      assert.is_true(status:is_staged())
    end)

    it('should return true for staged type change', function()
      local status = GitStatus('T  file.lua')
      assert.is_true(status:is_staged())
    end)

    it('should return true for staged deleted file', function()
      local status = GitStatus('D  file.lua')
      assert.is_true(status:is_staged())
    end)

    it('should return true for staged renamed file', function()
      local status = GitStatus('R  file.lua')
      assert.is_true(status:is_staged())
    end)

    it('should return true for staged copied file', function()
      local status = GitStatus('C  file.lua')
      assert.is_true(status:is_staged())
    end)

    it('should return true for staged with unstaged changes', function()
      local status = GitStatus('MM file.lua')
      assert.is_true(status:is_staged())
    end)

    it('should return false for only unstaged changes', function()
      local status = GitStatus(' M file.lua')
      assert.is_false(status:is_staged())
    end)

    it('should return false for untracked file', function()
      local status = GitStatus('?? file.lua')
      assert.is_false(status:is_staged())
    end)
  end)

  describe('is_unstaged', function()
    it('should return true for unstaged modification', function()
      local status = GitStatus(' M file.lua')
      assert.is_true(status:is_unstaged())
    end)

    it('should return true for unstaged type change', function()
      local status = GitStatus(' T file.lua')
      assert.is_true(status:is_unstaged())
    end)

    it('should return true for unstaged deletion', function()
      local status = GitStatus(' D file.lua')
      assert.is_true(status:is_unstaged())
    end)

    it('should return true for unstaged rename', function()
      local status = GitStatus(' R file.lua')
      assert.is_true(status:is_unstaged())
    end)

    it('should return true for unstaged copy', function()
      local status = GitStatus(' C file.lua')
      assert.is_true(status:is_unstaged())
    end)

    it('should return true for untracked file', function()
      local status = GitStatus('?? file.lua')
      assert.is_true(status:is_unstaged())
    end)

    it('should return true for staged with unstaged changes', function()
      local status = GitStatus('MM file.lua')
      assert.is_true(status:is_unstaged())
    end)

    it('should return false for only staged changes', function()
      local status = GitStatus('M  file.lua')
      assert.is_false(status:is_unstaged())
    end)
  end)

  describe('edge cases', function()
    it('should handle paths with spaces', function()
      local status = GitStatus('M  path with spaces.lua')
      eq(status.filename, 'path with spaces.lua')
    end)

    it('should handle paths with special characters', function()
      local status = GitStatus('M  file-name_test.lua')
      eq(status.filename, 'file-name_test.lua')
    end)

    it('should handle nested paths', function()
      local status = GitStatus('M  dir/subdir/file.lua')
      eq(status.filename, 'dir/subdir/file.lua')
    end)
  end)
end)
