local GutterSignAnnotator = require('vgit.ui.annotators.GutterSignAnnotator')

local eq = assert.are.same

describe('GutterSignAnnotator:', function()
  local annotator
  local sign_types

  before_each(function()
    annotator = GutterSignAnnotator()
    sign_types = {
      add = 'GitSignsAdd',
      remove = 'GitSignsDelete',
      change = 'GitSignsChange',
    }
  end)

  describe('annotate', function()
    it('should return empty array for empty hunks', function()
      local signs = annotator:annotate({}, sign_types)
      eq({}, signs)
    end)

    it('should produce signs for a single add hunk spanning lines 1-3', function()
      local hunks = {
        { type = 'add', top = 1, bot = 3 },
      }
      local signs = annotator:annotate(hunks, sign_types)

      eq(3, #signs)
      eq({ col = 0, name = 'GitSignsAdd' }, signs[1])
      eq({ col = 1, name = 'GitSignsAdd' }, signs[2])
      eq({ col = 2, name = 'GitSignsAdd' }, signs[3])
    end)

    it('should clamp col to 0 for remove hunk with top=0', function()
      local hunks = {
        { type = 'remove', top = 0, bot = 0 },
      }
      local signs = annotator:annotate(hunks, sign_types)

      eq(1, #signs)
      eq({ col = 0, name = 'GitSignsDelete' }, signs[1])
    end)

    it('should produce correct sign names for mixed hunk types', function()
      local hunks = {
        { type = 'add', top = 1, bot = 1 },
        { type = 'remove', top = 3, bot = 3 },
        { type = 'change', top = 5, bot = 6 },
      }
      local signs = annotator:annotate(hunks, sign_types)

      eq(4, #signs)
      eq('GitSignsAdd', signs[1].name)
      eq('GitSignsDelete', signs[2].name)
      eq('GitSignsChange', signs[3].name)
      eq('GitSignsChange', signs[4].name)
    end)

    it('should produce 1 sign for hunk with top == bot', function()
      local hunks = {
        { type = 'add', top = 5, bot = 5 },
      }
      local signs = annotator:annotate(hunks, sign_types)

      eq(1, #signs)
      eq({ col = 4, name = 'GitSignsAdd' }, signs[1])
    end)
  end)
end)
