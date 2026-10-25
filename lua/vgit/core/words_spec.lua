local words = require('vgit.core.words')

local eq = assert.are.same

describe('words:', function()
  describe('ranges', function()
    it('should give word_add and word_delete roles', function()
      eq(
        { { col_start = 6, col_end = 11, role = 'word_add' } },
        words.ranges({
          { 0, 'hello ' },
          { -1, 'world' },
        }, 'add')
      )

      eq(
        { { col_start = 0, col_end = 3, role = 'word_delete' } },
        words.ranges({
          { -1, 'old' },
        }, 'remove')
      )
    end)
  end)

  describe('overlay', function()
    it('should keep the roles in the overlay chunks', function()
      eq(
        { col = 6, texts = { { 'world', 'word_add' } } },
        words.overlay('hello world', { { col_start = 6, col_end = 11, role = 'word_add' } })
      )
    end)

    it('should return nil when nothing changed', function()
      assert.is_nil(words.overlay('same', {}))
    end)
  end)

  describe('overlay_for', function()
    it('should build the overlay from a change and its line', function()
      eq(
        { col = 6, texts = { { 'world', 'word_add' } } },
        words.overlay_for({
          type = 'add',
          word_diff = {
            { 0, 'hello ' },
            { -1, 'world' },
          },
        }, 'hello world')
      )
    end)

    it('should return nil when there is no change or no word diff', function()
      assert.is_nil(words.overlay_for(nil, 'x'))
      assert.is_nil(words.overlay_for({ type = 'add' }, 'x'))
    end)
  end)
end)
