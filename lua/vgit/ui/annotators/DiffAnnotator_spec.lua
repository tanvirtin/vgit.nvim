local DiffAnnotator = require('vgit.ui.annotators.DiffAnnotator')

local eq = assert.are.same

describe('DiffAnnotator:', function()
  describe('annotate_line', function()
    it('should return empty table when lnum_change is nil', function()
      local result = DiffAnnotator.annotate_line({})
      eq({}, result)
    end)

    it('should return sign for add change type', function()
      local result = DiffAnnotator.annotate_line({
        lnum_change = { lnum = 5, type = 'add' },
      })
      assert.is_not_nil(result)
      assert.is_not_nil(result.sign)
      assert.are.equal(4, result.sign.row)
      assert.are.equal('GitSignsAddLn', result.sign.name)
    end)

    it('should return sign for remove change type', function()
      local result = DiffAnnotator.annotate_line({
        lnum_change = { lnum = 3, type = 'remove' },
      })
      assert.is_not_nil(result)
      assert.is_not_nil(result.sign)
      assert.are.equal(2, result.sign.row)
      assert.are.equal('GitSignsDeleteLn', result.sign.name)
    end)

    it('should return void_text for void change type', function()
      local result = DiffAnnotator.annotate_line({
        lnum_change = { lnum = 7, type = 'void' },
      })
      assert.is_not_nil(result)
      assert.is_not_nil(result.void_text)
      assert.are.equal(6, result.void_text.row)
      assert.are.equal(0, result.void_text.col)
      assert.are.equal('GitLineNr', result.void_text.hl)
    end)

    it('should not have sign when scene_signs has no mapping for type', function()
      local result = DiffAnnotator.annotate_line({
        lnum_change = { lnum = 1, type = 'void' },
      })
      assert.is_nil(result.sign)
    end)
  end)

  describe('word_overlay', function()
    it('should cover the changed span, leaving the unchanged gaps uncoloured so syntax shows through', function()
      local overlay = DiffAnnotator.word_overlay('local x = 12 + y', {
        { col_start = 6, col_end = 7, hl_group = 'GitWordAdd' },
        { col_start = 11, col_end = 12, hl_group = 'GitWordAdd' },
      })

      eq(6, overlay.col)
      eq({ { 'x', 'GitWordAdd' }, { ' = 1', nil }, { '2', 'GitWordAdd' } }, overlay.texts)
    end)

    it('should return nil when nothing changed', function()
      assert.is_nil(DiffAnnotator.word_overlay('same', {}))
    end)
  end)

  describe('word_overlay_for', function()
    it('should build the overlay from a change and its line', function()
      eq(
        { col = 6, texts = { { 'world', 'GitWordAdd' } } },
        DiffAnnotator.word_overlay_for({
          type = 'add',
          word_diff = {
            { 0, 'hello ' },
            { -1, 'world' },
          },
        }, 'hello world')
      )
    end)

    it('should use GitWordDelete for a removed line', function()
      eq(
        { col = 0, texts = { { 'old', 'GitWordDelete' } } },
        DiffAnnotator.word_overlay_for({
          type = 'remove',
          word_diff = { { -1, 'old' } },
        }, 'old')
      )
    end)

    it('should return nil when there is no change or no word diff', function()
      assert.is_nil(DiffAnnotator.word_overlay_for(nil, 'x'))
      assert.is_nil(DiffAnnotator.word_overlay_for({ type = 'add' }, 'x'))
    end)
  end)

  describe('annotate_word', function()
    it('should return nil when lnum_change is nil', function()
      local result = DiffAnnotator.annotate_word({}, 1)
      assert.is_nil(result)
    end)

    it('should return nil when word_diff is nil', function()
      local result = DiffAnnotator.annotate_word({
        lnum_change = { lnum = 1, type = 'add' },
      }, 1)
      assert.is_nil(result)
    end)

    it('should mark the changed words of an add line as byte ranges', function()
      local result = DiffAnnotator.annotate_word({
        lnum_change = {
          lnum = 2,
          type = 'add',
          word_diff = {
            { 0, 'hello ' },
            { -1, 'world' },
          },
        },
      }, 2)
      assert.are.equal(1, result.row)
      eq({ { col_start = 6, col_end = 11, hl_group = 'GitWordAdd' } }, result.ranges)
    end)

    it('should use GitWordDelete for remove type', function()
      local result = DiffAnnotator.annotate_word({
        lnum_change = {
          lnum = 3,
          type = 'remove',
          word_diff = {
            { -1, 'deleted' },
            { 0, ' text' },
          },
        },
      }, 3)
      eq({ { col_start = 0, col_end = 7, hl_group = 'GitWordDelete' } }, result.ranges)
    end)

    it('should skip operation 1 (insertions in other side)', function()
      local result = DiffAnnotator.annotate_word({
        lnum_change = {
          lnum = 1,
          type = 'add',
          word_diff = {
            { 0, 'same' },
            { 1, 'inserted_elsewhere' },
            { -1, 'changed' },
          },
        },
      }, 1)
      eq({ { col_start = 4, col_end = 11, hl_group = 'GitWordAdd' } }, result.ranges)
    end)

    it('should handle empty word_diff', function()
      local result = DiffAnnotator.annotate_word({
        lnum_change = {
          lnum = 1,
          type = 'add',
          word_diff = {},
        },
      }, 1)
      eq({}, result.ranges)
    end)

    it('should count bytes, so ranges stay right after multibyte text', function()
      eq(
        { { col_start = 5, col_end = 6, hl_group = 'GitWordAdd' } },
        DiffAnnotator.word_ranges({ { 0, 'é = ' }, { -1, 'x' } }, 'add')
      )
    end)
  end)
end)
