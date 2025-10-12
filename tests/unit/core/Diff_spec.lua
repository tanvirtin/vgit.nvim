local Diff = require('vgit.core.diff.Diff')
local GitHunk = require('vgit.git.GitHunk')

local build_hunk = function(hunk)
  return setmetatable(hunk, GitHunk)
end

describe('Diff:', function()
  describe('generate', function()
    describe('unified', function()
      local layout_type = 'unified'

      it('should return correct code dto for a new file', function()
        local pre_diff_lines = { 'a', 'b', 'c', 'd', 'e' }
        local hunks = {
          build_hunk({
            top = 1,
            bot = 5,
            type = 'add',
            diff = { '+a', '+b', '+c', '+d', '+e' },
            stat = {
              added = 5,
              removed = 0,
            },
          }),
        }
        local diff_dto = Diff():generate(hunks, pre_diff_lines, layout_type)

        assert.are.same(diff_dto.lines, pre_diff_lines)
        assert.are.same(diff_dto.current_lines, {})
        assert.are.same(diff_dto.previous_lines, {})
        assert.are.same(diff_dto.hunks, hunks)
        assert.are.same(diff_dto.lnum_changes, {
          {
            buftype = 'current',
            lnum = 1,
            type = 'add',
          },
          {
            buftype = 'current',
            lnum = 2,
            type = 'add',
          },
          {
            buftype = 'current',
            lnum = 3,
            type = 'add',
          },
          {
            buftype = 'current',
            lnum = 4,
            type = 'add',
          },
          {
            buftype = 'current',
            lnum = 5,
            type = 'add',
          },
        })
        assert.are.same(diff_dto.marks, {
          {
            top = 1,
            bot = 5,
            top_relative = 1,
            bot_relative = 5,
            type = 'add',
          },
        })
        assert.are.same(diff_dto.stat, {
          added = 5,
          removed = 0,
        })
      end)

      it('should return correct code dto for a changed file', function()
        local pre_diff_lines = { 'a', 'b', 'c', 'd', 'e' }
        local hunks = {
          build_hunk({
            bot = 0,
            diff = { '-a' },
            header = '@@ -1,1 +0,0 @@',
            stat = {
              added = 0,
              removed = 1,
            },
            top = 0,
            type = 'remove',
          }),
          build_hunk({
            bot = 3,
            diff = { '-c', '+a', '+k' },
            header = '@@ -3,1 +2,2 @@',
            stat = {
              added = 2,
              removed = 1,
            },
            top = 2,
            type = 'change',
          }),
          build_hunk({
            bot = 5,
            diff = { '-e', '+l' },
            header = '@@ -5,1 +5,1 @@',
            stat = {
              added = 1,
              removed = 1,
            },
            top = 5,
            type = 'change',
          }),
        }
        local diff_dto = Diff():generate(hunks, pre_diff_lines, layout_type)

        assert.are.same(diff_dto.lines, {
          'a',
          'a',
          'c',
          'b',
          'c',
          'd',
          'e',
          'e',
        })
        assert.are.same(diff_dto.current_lines, {})
        assert.are.same(diff_dto.previous_lines, {})
        assert.are.same(diff_dto.lnum_changes, {
          {
            buftype = 'current',
            lnum = 1,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 3,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 4,
            type = 'add',
          },
          {
            buftype = 'current',
            lnum = 5,
            type = 'add',
          },
          {
            buftype = 'current',
            lnum = 7,
            type = 'remove',
            word_diff = { { -1, 'e' }, { 1, 'l' } },
          },
          {
            buftype = 'current',
            lnum = 8,
            type = 'add',
            word_diff = { { -1, 'l' }, { 1, 'e' } },
          },
        })
        assert.are.same(diff_dto.marks, {
          {
            top = 1,
            bot = 1,
            top_relative = 0,
            bot_relative = 0,
            type = 'remove',
          },
          {
            top = 3,
            bot = 5,
            top_relative = 2,
            bot_relative = 3,
            type = 'change',
          },
          {
            top = 7,
            bot = 8,
            top_relative = 5,
            bot_relative = 5,
            type = 'change',
          },
        })
        assert.are.same(diff_dto.stat, {
          added = 3,
          removed = 3,
        })
      end)
    end)

    describe('split', function()
      local layout_type = 'split'

      it('should return correct code dto for a new file', function()
        local pre_diff_lines = { 'a', 'b', 'c', 'd', 'e' }
        local hunks = {
          build_hunk({
            top = 1,
            bot = 5,
            type = 'add',
            diff = { '+a', '+b', '+c', '+d', '+e' },
            stat = {
              added = 5,
              removed = 0,
            },
          }),
        }
        local diff_dto = Diff():generate(hunks, pre_diff_lines, layout_type)

        assert.are.same(diff_dto.lines, {})
        assert.are.same(diff_dto.current_lines, pre_diff_lines)
        assert.are.same(diff_dto.previous_lines, { '', '', '', '', '' })
        assert.are.same(diff_dto.hunks, hunks)
        assert.are.same(diff_dto.lnum_changes, {
          {
            buftype = 'previous',
            lnum = 1,
            type = 'void',
          },
          {
            buftype = 'current',
            lnum = 1,
            type = 'add',
          },
          {
            buftype = 'previous',
            lnum = 2,
            type = 'void',
          },
          {
            buftype = 'current',
            lnum = 2,
            type = 'add',
          },
          {
            buftype = 'previous',
            lnum = 3,
            type = 'void',
          },
          {
            buftype = 'current',
            lnum = 3,
            type = 'add',
          },
          {
            buftype = 'previous',
            lnum = 4,
            type = 'void',
          },
          {
            buftype = 'current',
            lnum = 4,
            type = 'add',
          },
          {
            buftype = 'previous',
            lnum = 5,
            type = 'void',
          },
          {
            buftype = 'current',
            lnum = 5,
            type = 'add',
          },
        })
        assert.are.same(diff_dto.marks, {
          {
            top = 1,
            bot = 5,
            top_relative = 1,
            bot_relative = 5,
            type = 'add',
          },
        })
        assert.are.same(diff_dto.stat, {
          added = 5,
          removed = 0,
        })
      end)

      it('should return correct code dto for a changed file', function()
        local pre_diff_lines = { 'a', 'b', 'c', 'd', 'e' }
        local hunks = {
          build_hunk({
            bot = 0,
            diff = { '-a' },
            header = '@@ -1,1 +0,0 @@',
            stat = {
              added = 0,
              removed = 1,
            },
            top = 0,
            type = 'remove',
          }),
          build_hunk({
            bot = 3,
            diff = { '-c', '+a', '+k' },
            header = '@@ -3,1 +2,2 @@',
            stat = {
              added = 2,
              removed = 1,
            },
            top = 2,
            type = 'change',
          }),
          build_hunk({
            bot = 5,
            diff = { '-e', '+l' },
            header = '@@ -5,1 +5,1 @@',
            stat = {
              added = 1,
              removed = 1,
            },
            top = 5,
            type = 'change',
          }),
        }
        local diff_dto = Diff():generate(hunks, pre_diff_lines, layout_type)

        assert.are.same(diff_dto.lines, {})
        assert.are.same(diff_dto.current_lines, { '', 'a', 'a', 'k', 'd', 'l' })
        assert.are.same(diff_dto.previous_lines, { 'a', 'a', 'c', '', 'd', 'e' })
        assert.are.same(diff_dto.hunks, hunks)
        assert.are.same(diff_dto.lnum_changes, {
          {
            buftype = 'current',
            lnum = 1,
            type = 'void',
          },
          {
            buftype = 'previous',
            lnum = 1,
            type = 'remove',
          },
          {
            buftype = 'previous',
            lnum = 3,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 3,
            type = 'add',
          },
          {
            buftype = 'current',
            lnum = 4,
            type = 'add',
          },
          {
            buftype = 'previous',
            lnum = 4,
            type = 'void',
          },
          {
            buftype = 'previous',
            lnum = 6,
            type = 'remove',
            word_diff = { { -1, 'e' }, { 1, 'l' } },
          },
          {
            buftype = 'current',
            lnum = 6,
            type = 'add',
            word_diff = { { -1, 'l' }, { 1, 'e' } },
          },
        })
        assert.are.same(diff_dto.marks, {
          {
            top = 1,
            bot = 1,
            top_relative = 0,
            bot_relative = 0,
            type = 'remove',
          },
          {
            top = 3,
            bot = 4,
            top_relative = 2,
            bot_relative = 3,
            type = 'change',
          },
          {
            top = 6,
            bot = 6,
            top_relative = 5,
            bot_relative = 5,
            type = 'change',
          },
        })
        assert.are.same(diff_dto.stat, {
          added = 3,
          removed = 3,
        })
      end)
    end)
  end)

  describe('constructor', function()
    it('should initialize with no arguments', function()
      local diff = Diff()
      assert.is_not_nil(diff)
    end)

    it('should initialize with opts parameter', function()
      local diff = Diff({ some_opt = true })
      assert.is_not_nil(diff)
    end)
  end)

  describe('call_deleted', function()
    local pre_diff_lines
    local hunks

    before_each(function()
      pre_diff_lines = { 'a', 'b', 'c', 'd', 'e' }
      hunks = {
        build_hunk({
          bot = 5,
          diff = { '+a', '+b', '+c', '+d', '+e' },
          stat = {
            added = 0,
            removed = 5,
          },
          top = 1,
          type = 'remove',
        }),
      }
    end)

    describe('unified', function()
      it('should return correct code dto', function()
        local diff_dto = Diff():generate_unified_deleted(hunks, pre_diff_lines)

        assert.are.same(diff_dto.lines, pre_diff_lines)
        assert.are.same(diff_dto.current_lines, {})
        assert.are.same(diff_dto.previous_lines, {})
        assert.are.same(diff_dto.hunks, hunks)
        assert.are.same(diff_dto.lnum_changes, {
          {
            buftype = 'current',
            lnum = 1,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 2,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 3,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 4,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 5,
            type = 'remove',
          },
        })
        assert.are.same(diff_dto.marks, {
          {
            bot = 5,
            top = 1,
            type = 'remove',
          },
        })
        assert.are.same(diff_dto.stat, {
          added = 0,
          removed = 5,
        })
      end)
    end)

    describe('split', function()
      it('should return correct code dto', function()
        local diff_dto = Diff():generate_split_deleted(hunks, pre_diff_lines)

        assert.are.same(diff_dto.lines, {})
        assert.are.same(diff_dto.current_lines, { '', '', '', '', '' })
        assert.are.same(diff_dto.previous_lines, { 'a', 'b', 'c', 'd', 'e' })
        assert.are.same(diff_dto.hunks, hunks)
        assert.are.same(diff_dto.lnum_changes, {
          {
            buftype = 'previous',
            lnum = 1,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 1,
            type = 'void',
          },
          {
            buftype = 'previous',
            lnum = 2,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 2,
            type = 'void',
          },
          {
            buftype = 'previous',
            lnum = 3,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 3,
            type = 'void',
          },
          {
            buftype = 'previous',
            lnum = 4,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 4,
            type = 'void',
          },
          {
            buftype = 'previous',
            lnum = 5,
            type = 'remove',
          },
          {
            buftype = 'current',
            lnum = 5,
            type = 'void',
          },
        })
        assert.are.same(diff_dto.marks, {
          {
            bot = 5,
            top = 1,
            type = 'remove',
          },
        })
        assert.are.same(diff_dto.stat, {
          added = 0,
          removed = 5,
        })
      end)
    end)
  end)

  describe('conflict handling', function()
    describe('generate with conflicts flag', function()
      it('should route to generate_unified_conflict for unified layout', function()
        local lines = { '<<<<<<< HEAD', 'version1', '=======', 'version2', '>>>>>>>' }
        local conflicts = {
          {
            current = { top = 2, bot = 2 },
            ancestor = nil,
            middle = { top = 3, bot = 3 },
            incoming = { top = 4, bot = 4 },
          },
        }

        local diff_dto = Diff():generate({}, lines, 'unified', { conflicts = conflicts })

        assert.is_not_nil(diff_dto)
        assert.are.same(diff_dto.lines, lines)
      end)

      it('should route to generate_split_conflict for split layout', function()
        local lines = { '<<<<<<< HEAD', 'version1', '=======', 'version2', '>>>>>>>' }
        local conflicts = {
          {
            current = { top = 2, bot = 2 },
            ancestor = nil,
            middle = { top = 3, bot = 3 },
            incoming = { top = 4, bot = 4 },
          },
        }

        local diff_dto = Diff():generate({}, lines, 'split', { conflicts = conflicts })

        assert.is_not_nil(diff_dto)
        assert.is_true(#diff_dto.current_lines > 0 or #diff_dto.previous_lines > 0)
      end)
    end)

    describe('generate_unified_conflict', function()
      it('should return correct dto for single conflict', function()
        local lines = { '<<<<<<< HEAD', 'version1', '=======', 'version2', '>>>>>>>' }
        local conflicts = {
          {
            current = { top = 2, bot = 2 },
            ancestor = nil,
            middle = { top = 3, bot = 3 },
            incoming = { top = 4, bot = 4 },
          },
        }

        local diff_dto = Diff():generate_unified_conflict(conflicts, lines)

        assert.is_not_nil(diff_dto)
        assert.are.same(diff_dto.lines, lines)
        assert.is_true(#diff_dto.lnum_changes > 0)
      end)

      it('should handle empty conflict sections', function()
        local lines = { '<<<<<<< HEAD', '=======', '>>>>>>>' }
        local conflicts = {
          {
            current = { top = 1, bot = 1 },
            ancestor = nil,
            middle = { top = 2, bot = 2 },
            incoming = { top = 3, bot = 3 },
          },
        }

        local diff_dto = Diff():generate_unified_conflict(conflicts, lines)

        assert.is_not_nil(diff_dto)
        assert.are.same(diff_dto.lines, lines)
      end)
    end)

    describe('generate_split_conflict', function()
      it('should return correct dto for single conflict', function()
        local lines = { '<<<<<<< HEAD', 'version1', '=======', 'version2', '>>>>>>>' }
        local conflicts = {
          {
            current = { top = 2, bot = 2 },
            ancestor = nil,
            middle = { top = 3, bot = 3 },
            incoming = { top = 4, bot = 4 },
          },
        }

        local diff_dto = Diff():generate_split_conflict(conflicts, lines)

        assert.is_not_nil(diff_dto)
        assert.is_true(#diff_dto.current_lines > 0)
      end)

      it('should handle multiple conflicts', function()
        local lines = {
          '<<<<<<< HEAD',
          'v1_1',
          '=======',
          'v2_1',
          '>>>>>>>',
          'middle',
          '<<<<<<< HEAD',
          'v1_2',
          '=======',
          'v2_2',
          '>>>>>>>',
        }
        local conflicts = {
          {
            current = { top = 2, bot = 2 },
            ancestor = nil,
            middle = { top = 3, bot = 3 },
            incoming = { top = 4, bot = 4 },
          },
          {
            current = { top = 8, bot = 8 },
            ancestor = nil,
            middle = { top = 9, bot = 9 },
            incoming = { top = 10, bot = 10 },
          },
        }

        local diff_dto = Diff():generate_split_conflict(conflicts, lines)

        assert.is_not_nil(diff_dto)
        assert.is_true(#diff_dto.current_lines > 0)
        assert.is_true(#diff_dto.previous_lines > 0)
      end)
    end)
  end)

  describe('edge cases', function()
    it('should handle empty hunks array', function()
      local diff_dto = Diff():generate({}, { 'line1', 'line2' }, 'unified')

      assert.is_not_nil(diff_dto)
      assert.are.equal(#diff_dto.lnum_changes, 0)
      assert.are.equal(#diff_dto.marks, 0)
    end)

    it('should handle empty lines array', function()
      local hunks = {
        build_hunk({
          top = 1,
          bot = 0,
          type = 'add',
          diff = {},
          stat = { added = 0, removed = 0 },
        }),
      }

      local diff_dto = Diff():generate(hunks, {}, 'unified')

      assert.is_not_nil(diff_dto)
      assert.are.same(diff_dto.lines, {})
    end)

    it('should handle single line files', function()
      local hunks = {
        build_hunk({
          top = 1,
          bot = 1,
          type = 'add',
          diff = { '+single' },
          stat = { added = 1, removed = 0 },
        }),
      }

      local diff_dto = Diff():generate(hunks, { 'single' }, 'unified')

      assert.is_not_nil(diff_dto)
      assert.are.equal(#diff_dto.lines, 1)
      assert.are.equal(#diff_dto.lnum_changes, 1)
    end)

    it('should handle large files', function()
      local lines = {}
      for i = 1, 1000 do
        lines[i] = 'line ' .. i
      end

      local hunks = {
        build_hunk({
          top = 1,
          bot = 1000,
          type = 'add',
          diff = {},
          stat = { added = 1000, removed = 0 },
        }),
      }

      local diff_dto = Diff():generate(hunks, lines, 'unified')

      assert.is_not_nil(diff_dto)
      assert.are.equal(#diff_dto.lines, 1000)
    end)
  end)

  describe('generate method routing', function()
    it('should call generate_unified_deleted when is_deleted flag is true for unified', function()
      local lines = { 'a', 'b', 'c' }
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'remove',
          diff = { '-a', '-b', '-c' },
          stat = { added = 0, removed = 3 },
        }),
      }

      local diff_dto = Diff():generate(hunks, lines, 'unified', { is_deleted = true })

      assert.is_not_nil(diff_dto)
      assert.are.same(diff_dto.lines, lines)
    end)

    it('should call generate_split_deleted when is_deleted flag is true for split', function()
      local lines = { 'a', 'b', 'c' }
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'remove',
          diff = { '-a', '-b', '-c' },
          stat = { added = 0, removed = 3 },
        }),
      }

      local diff_dto = Diff():generate(hunks, lines, 'split', { is_deleted = true })

      assert.is_not_nil(diff_dto)
      assert.are.same(diff_dto.previous_lines, lines)
    end)

    it('should call generate_unified when shape is unified without flags', function()
      local lines = { 'a', 'b', 'c' }
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'add',
          diff = { '+a', '+b', '+c' },
          stat = { added = 3, removed = 0 },
        }),
      }

      local diff_dto = Diff():generate(hunks, lines, 'unified')

      assert.is_not_nil(diff_dto)
      assert.are.same(diff_dto.lines, lines)
    end)

    it('should call generate_split when shape is split without flags', function()
      local lines = { 'a', 'b', 'c' }
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'add',
          diff = { '+a', '+b', '+c' },
          stat = { added = 3, removed = 0 },
        }),
      }

      local diff_dto = Diff():generate(hunks, lines, 'split')

      assert.is_not_nil(diff_dto)
      assert.are.same(diff_dto.current_lines, lines)
    end)
  end)

  describe('error handling', function()
    it('should return valid result with empty hunks array', function()
      local diff = Diff()
      local result = diff:generate({}, { 'a', 'b', 'c' }, 'unified')

      assert.is_not_nil(result)
      assert.are.equal(#result.hunks, 0)
      assert.are.same(result.lines, { 'a', 'b', 'c' })
    end)

    it('should require valid shape parameter', function()
      local diff = Diff()
      local result, error_msg = pcall(function()
        return diff:generate({}, { 'a', 'b', 'c' }, nil)
      end)

      assert.is_false(result)
    end)

    it('should require shape to be either unified or split', function()
      local diff = Diff()
      local result, error_msg = pcall(function()
        return diff:generate({}, { 'a', 'b', 'c' }, 'invalid_shape')
      end)

      assert.is_false(result)
    end)

    it('should handle opts parameter being nil gracefully', function()
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'add',
          diff = { '+a', '+b', '+c' },
          stat = { added = 3, removed = 0 },
        }),
      }

      local diff = Diff()
      local result = diff:generate(hunks, { 'a', 'b', 'c' }, 'unified', nil)

      assert.is_not_nil(result)
      assert.are.same(result.lines, { 'a', 'b', 'c' })
    end)

    it('should properly handle generate_unified_deleted with valid hunks', function()
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'remove',
          diff = { '-a', '-b', '-c' },
          stat = { added = 0, removed = 3 },
        }),
      }

      local diff = Diff()
      local result = diff:generate_unified_deleted(hunks, { 'a', 'b', 'c' })

      assert.is_not_nil(result)
      assert.are.same(result.lines, { 'a', 'b', 'c' })
    end)

    it('should properly handle generate_split_deleted with valid hunks', function()
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'remove',
          diff = { '-a', '-b', '-c' },
          stat = { added = 0, removed = 3 },
        }),
      }

      local diff = Diff()
      local result = diff:generate_split_deleted(hunks, { 'a', 'b', 'c' })

      assert.is_not_nil(result)
      assert.are.same(result.previous_lines, { 'a', 'b', 'c' })
    end)

    it('should properly handle generate_unified_conflict with empty conflicts', function()
      local diff = Diff()
      local result = diff:generate_unified_conflict({}, { 'line1', 'line2' })

      assert.is_not_nil(result)
      assert.are.equal(#result.lnum_changes, 0)
    end)

    it('should properly handle generate_split_conflict with empty conflicts', function()
      local diff = Diff()
      local result = diff:generate_split_conflict({}, { 'line1', 'line2' })

      assert.is_not_nil(result)
      assert.are.equal(#result.current_lines, 2)
      assert.are.equal(#result.previous_lines, 2)
    end)

    it('should not modify input tables when generating diff', function()
      local original_lines = { 'a', 'b', 'c' }
      local hunks = {
        build_hunk({
          top = 1,
          bot = 3,
          type = 'add',
          diff = { '+a', '+b', '+c' },
          stat = { added = 3, removed = 0 },
        }),
      }

      local diff = Diff()
      diff:generate(hunks, original_lines, 'unified')

      assert.are.same(original_lines, { 'a', 'b', 'c' })
    end)
  end)
end)
