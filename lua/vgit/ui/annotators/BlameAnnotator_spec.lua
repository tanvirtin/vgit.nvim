local BlameAnnotator = require('vgit.ui.annotators.BlameAnnotator')

local eq = assert.are.same

describe('BlameAnnotator:', function()
  describe('annotate', function()
    it('should return text record for normal blame', function()
      local blame = { author = 'John', commit_hash = 'abc123' }
      local config = {}
      local format_fn = function(b, c)
        return b.author .. ' ' .. b.commit_hash
      end

      local result = BlameAnnotator.annotate(blame, 5, config, format_fn)

      eq({
        text = 'John abc123',
        hl = 'GitComment',
        row = 4,
        col = 0,
        pos = 'eol',
      }, result)
    end)

    it('should return nil when format_fn returns non-string', function()
      local blame = { author = 'John' }
      local config = {}
      local format_fn = function()
        return nil
      end

      local result = BlameAnnotator.annotate(blame, 1, config, format_fn)

      assert.is_nil(result)
    end)

    it('should return nil when format_fn returns a number', function()
      local blame = { author = 'John' }
      local config = {}
      local format_fn = function()
        return 42
      end

      local result = BlameAnnotator.annotate(blame, 1, config, format_fn)

      assert.is_nil(result)
    end)

    it('should set row to lnum - 1', function()
      local blame = { author = 'Test' }
      local config = {}
      local format_fn = function()
        return 'text'
      end

      local result = BlameAnnotator.annotate(blame, 10, config, format_fn)

      eq(9, result.row)
    end)

    it('should pass blame and config to format_fn', function()
      local received_blame, received_config
      local blame = { author = 'Jane' }
      local config = { key = 'value' }
      local format_fn = function(b, c)
        received_blame = b
        received_config = c
        return 'formatted'
      end

      BlameAnnotator.annotate(blame, 1, config, format_fn)

      eq(blame, received_blame)
      eq(config, received_config)
    end)
  end)
end)
