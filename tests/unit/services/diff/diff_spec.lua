local diff_service = require('vgit.services.diff')
local Hunk = require('vgit.services.git.models.Hunk')

local build_hunk = function(hunk) return setmetatable(hunk, Hunk) end

describe('diff_service:', function()
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
        local diff_dto = diff_service:generate(hunks, pre_diff_lines, layout_type)

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
        local diff_dto = diff_service:generate(hunks, pre_diff_lines, layout_type)

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
        local diff_dto = diff_service:generate(hunks, pre_diff_lines, layout_type)

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
        local diff_dto = diff_service:generate(hunks, pre_diff_lines, layout_type)

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
        local diff_dto = diff_service:generate_unified_deleted(hunks, pre_diff_lines)

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
        local diff_dto = diff_service:generate_split_deleted(hunks, pre_diff_lines)

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
end)
