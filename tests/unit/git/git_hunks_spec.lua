local git_hunks = require('vgit.git.git_hunks')
local GitHunk = require('vgit.git.GitHunk')

describe('git_hunks:', function()
  describe('live', function()
    it('should return empty hunks when there are no changes', function()
      local original_lines = { 'a', 'b', 'c' }
      local current_lines = { 'a', 'b', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.same(hunks, {})
    end)

    it('should detect added lines at the beginning', function()
      local original_lines = { 'b', 'c', 'd' }
      local current_lines = { 'a', 'b', 'c', 'd' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 1)
      assert.are.same(hunks[1].diff, { '+a' })
      assert.are.same(hunks[1].stat, { added = 1, removed = 0 })
    end)

    it('should detect added lines at the end', function()
      local original_lines = { 'a', 'b', 'c' }
      local current_lines = { 'a', 'b', 'c', 'd' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 4)
      assert.are.equal(hunks[1].bot, 4)
      assert.are.same(hunks[1].diff, { '+d' })
      assert.are.same(hunks[1].stat, { added = 1, removed = 0 })
    end)

    it('should detect added lines in the middle', function()
      local original_lines = { 'a', 'c' }
      local current_lines = { 'a', 'b', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 2)
      assert.are.same(hunks[1].diff, { '+b' })
      assert.are.same(hunks[1].stat, { added = 1, removed = 0 })
    end)

    it('should detect multiple added lines', function()
      local original_lines = { 'a', 'd' }
      local current_lines = { 'a', 'b', 'c', 'd' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 3)
      assert.are.same(hunks[1].diff, { '+b', '+c' })
      assert.are.same(hunks[1].stat, { added = 2, removed = 0 })
    end)

    it('should detect removed lines at the beginning', function()
      local original_lines = { 'a', 'b', 'c', 'd' }
      local current_lines = { 'b', 'c', 'd' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'remove')
      assert.are.equal(hunks[1].top, 0)
      assert.are.equal(hunks[1].bot, 0)
      assert.are.same(hunks[1].diff, { '-a' })
      assert.are.same(hunks[1].stat, { added = 0, removed = 1 })
    end)

    it('should detect removed lines at the end', function()
      local original_lines = { 'a', 'b', 'c', 'd' }
      local current_lines = { 'a', 'b', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'remove')
      assert.are.equal(hunks[1].top, 3)
      assert.are.equal(hunks[1].bot, 3)
      assert.are.same(hunks[1].diff, { '-d' })
      assert.are.same(hunks[1].stat, { added = 0, removed = 1 })
    end)

    it('should detect removed lines in the middle', function()
      local original_lines = { 'a', 'b', 'c' }
      local current_lines = { 'a', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'remove')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 1)
      assert.are.same(hunks[1].diff, { '-b' })
      assert.are.same(hunks[1].stat, { added = 0, removed = 1 })
    end)

    it('should detect multiple removed lines', function()
      local original_lines = { 'a', 'b', 'c', 'd' }
      local current_lines = { 'a', 'd' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'remove')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 1)
      assert.are.same(hunks[1].diff, { '-b', '-c' })
      assert.are.same(hunks[1].stat, { added = 0, removed = 2 })
    end)

    it('should detect changed lines', function()
      local original_lines = { 'a', 'b', 'c' }
      local current_lines = { 'a', 'x', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'change')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 2)
      assert.are.same(hunks[1].diff, { '-b', '+x' })
      assert.are.same(hunks[1].stat, { added = 1, removed = 1 })
    end)

    it('should detect multiple changed lines', function()
      local original_lines = { 'a', 'b', 'c', 'd' }
      local current_lines = { 'a', 'x', 'y', 'd' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'change')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 3)
      assert.are.same(hunks[1].diff, { '-b', '-c', '+x', '+y' })
      assert.are.same(hunks[1].stat, { added = 2, removed = 2 })
    end)

    it('should detect asymmetric changes (more added than removed)', function()
      local original_lines = { 'a', 'b', 'd' }
      local current_lines = { 'a', 'x', 'y', 'z', 'd' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'change')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 4)
      assert.are.same(hunks[1].diff, { '-b', '+x', '+y', '+z' })
      assert.are.same(hunks[1].stat, { added = 3, removed = 1 })
    end)

    it('should detect asymmetric changes (more removed than added)', function()
      local original_lines = { 'a', 'b', 'c', 'd', 'e' }
      local current_lines = { 'a', 'x', 'e' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'change')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 2)
      assert.are.same(hunks[1].diff, { '-b', '-c', '-d', '+x' })
      assert.are.same(hunks[1].stat, { added = 1, removed = 3 })
    end)

    it('should detect multiple separate hunks', function()
      local original_lines = { 'a', 'b', 'c', 'd', 'e', 'f' }
      local current_lines = { 'a', 'x', 'c', 'd', 'y', 'f' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 2)

      assert.are.equal(hunks[1].type, 'change')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 2)
      assert.are.same(hunks[1].diff, { '-b', '+x' })
      assert.are.same(hunks[1].stat, { added = 1, removed = 1 })

      assert.are.equal(hunks[2].type, 'change')
      assert.are.equal(hunks[2].top, 5)
      assert.are.equal(hunks[2].bot, 5)
      assert.are.same(hunks[2].diff, { '-e', '+y' })
      assert.are.same(hunks[2].stat, { added = 1, removed = 1 })
    end)

    it('should detect all lines removed (file emptied)', function()
      local original_lines = { 'a', 'b', 'c' }
      local current_lines = {}

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'remove')
      assert.are.equal(hunks[1].top, 0)
      assert.are.equal(hunks[1].bot, 0)
      assert.are.same(hunks[1].diff, { '-a', '-b', '-c' })
      assert.are.same(hunks[1].stat, { added = 0, removed = 3 })
    end)

    it('should detect new file (all lines added)', function()
      local original_lines = {}
      local current_lines = { 'a', 'b', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 3)
      assert.are.same(hunks[1].diff, { '+a', '+b', '+c' })
      assert.are.same(hunks[1].stat, { added = 3, removed = 0 })
    end)

    it('should handle empty lines in diff', function()
      local original_lines = { 'a', '', 'c' }
      local current_lines = { 'a', 'b', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'change')
      assert.are.same(hunks[1].diff, { '-', '+b' })
    end)

    it('should handle whitespace-only changes', function()
      local original_lines = { 'a', 'b', 'c' }
      local current_lines = { 'a', '  b  ', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'change')
      assert.are.same(hunks[1].diff, { '-b', '+  b  ' })
    end)

    it('should handle complex multi-hunk scenario', function()
      local original_lines = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i' }
      local current_lines = { 'a', 'x', 'c', 'd', 'f', 'g', 'y', 'z', 'i' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 3)

      assert.are.equal(hunks[1].type, 'change')
      assert.are.equal(hunks[1].top, 2)
      assert.are.equal(hunks[1].bot, 2)

      assert.are.equal(hunks[2].type, 'remove')
      assert.are.equal(hunks[2].top, 4)
      assert.are.equal(hunks[2].bot, 4)

      assert.are.equal(hunks[3].type, 'change')
      assert.are.equal(hunks[3].top, 7)
      assert.are.equal(hunks[3].bot, 8)
    end)
  end)

  describe('custom', function()
    it('should generate untracked file hunk', function()
      local lines = { 'a', 'b', 'c' }

      local hunks = git_hunks.custom(lines, { untracked = true })

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 3)
      assert.are.same(hunks[1].diff, { '+a', '+b', '+c' })
      assert.are.same(hunks[1].stat, { added = 3, removed = 0 })
      assert.truthy(hunks[1].header:match('^@@ %-0,0 %+1,3 @@'))
    end)

    it('should generate deleted file hunk', function()
      local lines = { 'a', 'b', 'c' }

      local hunks = git_hunks.custom(lines, { deleted = true })

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'remove')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 3)
      assert.are.same(hunks[1].diff, { '+a', '+b', '+c' })
      assert.are.same(hunks[1].stat, { added = 0, removed = 3 })
      assert.truthy(hunks[1].header:match('^@@ %-1,3 %+0,0 @@'))
    end)

    it('should handle empty file for untracked', function()
      local lines = {}

      local hunks = git_hunks.custom(lines, { untracked = true })

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 0)
      assert.are.same(hunks[1].diff, {})
      assert.are.same(hunks[1].stat, { added = 0, removed = 0 })
    end)

    it('should handle single line for untracked', function()
      local lines = { 'hello world' }

      local hunks = git_hunks.custom(lines, { untracked = true })

      assert.are.equal(#hunks, 1)
      assert.are.equal(hunks[1].type, 'add')
      assert.are.equal(hunks[1].top, 1)
      assert.are.equal(hunks[1].bot, 1)
      assert.are.same(hunks[1].diff, { '+hello world' })
      assert.are.same(hunks[1].stat, { added = 1, removed = 0 })
    end)
  end)

  describe('GitHunk integration', function()
    it('should return valid GitHunk instances', function()
      local original_lines = { 'a', 'b' }
      local current_lines = { 'a', 'x' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.truthy(hunks[1]:is(GitHunk))
    end)

    it('should have proper hunk header format', function()
      local original_lines = { 'a', 'b', 'c' }
      local current_lines = { 'a', 'x', 'c' }

      local hunks = git_hunks.live(nil, original_lines, current_lines)

      assert.are.equal(#hunks, 1)
      assert.truthy(hunks[1].header)
      assert.truthy(hunks[1].header:match('^@@ '))
      assert.truthy(hunks[1].header:match('@@ %-(%d+),(%d+) %+(%d+),(%d+) @@'))
    end)
  end)
end)
