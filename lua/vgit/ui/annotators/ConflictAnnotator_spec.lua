local ConflictAnnotator = require('vgit.ui.annotators.ConflictAnnotator')

local eq = assert.are.same

describe('ConflictAnnotator:', function()
  local annotator

  before_each(function()
    annotator = ConflictAnnotator()
  end)

  describe('annotate', function()
    it('should produce correct signs and texts for basic conflict without ancestor', function()
      local conflict = {
        current = { top = 1, bot = 3 },
        ancestor = nil,
        middle = { top = 4, bot = 4 },
        incoming = { top = 5, bot = 7 },
      }

      local result = annotator:annotate(conflict)

      -- Signs: 1 current mark + 2 current body + 1 middle + 2 incoming body + 1 incoming mark = 7
      eq(7, #result.signs)

      -- Current mark
      eq({ col = 0, name = 'GitConflictCurrentMark' }, result.signs[1])

      -- Current body lines 2-3
      eq({ col = 1, name = 'GitConflictCurrent' }, result.signs[2])
      eq({ col = 2, name = 'GitConflictCurrent' }, result.signs[3])

      -- Middle
      eq({ col = 3, name = 'GitConflictMiddle' }, result.signs[4])

      -- Incoming body lines 5-6
      eq({ col = 4, name = 'GitConflictIncoming' }, result.signs[5])
      eq({ col = 5, name = 'GitConflictIncoming' }, result.signs[6])

      -- Incoming mark
      eq({ col = 6, name = 'GitConflictIncomingMark' }, result.signs[7])

      -- Texts
      eq(2, #result.texts)
      eq('(Current Change)', result.texts[1].text)
      eq('GitComment', result.texts[1].hl)
      eq(0, result.texts[1].row)
      eq('eol', result.texts[1].pos)

      eq('(Incoming Change)', result.texts[2].text)
      eq('GitComment', result.texts[2].hl)
      eq(6, result.texts[2].row)
      eq('eol', result.texts[2].pos)
    end)

    it('should include ancestor signs when ancestor is present', function()
      local conflict = {
        current = { top = 1, bot = 2 },
        ancestor = { top = 3, bot = 5 },
        middle = { top = 6, bot = 6 },
        incoming = { top = 7, bot = 8 },
      }

      local result = annotator:annotate(conflict)

      -- Find ancestor signs
      local ancestor_mark_found = false
      local ancestor_body_count = 0
      for _, sign in ipairs(result.signs) do
        if sign.name == 'GitConflictAncestorMark' then ancestor_mark_found = true end
        if sign.name == 'GitConflictAncestor' then ancestor_body_count = ancestor_body_count + 1 end
      end

      assert.is_true(ancestor_mark_found)
      eq(2, ancestor_body_count)
    end)

    it('should handle single-line sections', function()
      local conflict = {
        current = { top = 1, bot = 1 },
        ancestor = nil,
        middle = { top = 2, bot = 2 },
        incoming = { top = 3, bot = 3 },
      }

      local result = annotator:annotate(conflict)

      -- Current: 1 mark, 0 body (top+1 > bot for single line)
      -- Middle: 1 sign
      -- Incoming: 0 body (top > bot-1 for single line), 1 mark
      eq(3, #result.signs)
      eq('GitConflictCurrentMark', result.signs[1].name)
      eq('GitConflictMiddle', result.signs[2].name)
      eq('GitConflictIncomingMark', result.signs[3].name)
    end)

    it('should produce text labels at correct positions', function()
      local conflict = {
        current = { top = 10, bot = 12 },
        ancestor = nil,
        middle = { top = 13, bot = 13 },
        incoming = { top = 14, bot = 16 },
      }

      local result = annotator:annotate(conflict)

      eq(9, result.texts[1].row)
      eq(15, result.texts[2].row)
    end)
  end)
end)
