local SyntaxMappingAnnotator = require('vgit.ui.annotators.SyntaxMappingAnnotator')

local eq = assert.are.same

describe('SyntaxMappingAnnotator:', function()
  local annotator

  before_each(function()
    annotator = SyntaxMappingAnnotator()
  end)

  describe('clear_cache', function()
    it('should delegate to SyntaxAnnotator', function()
      annotator._syntax_annotator:_cache_put('ts_key', { 'ts_data' })

      annotator:clear_cache()

      eq({}, annotator._syntax_annotator._cache)
      eq({}, annotator._syntax_annotator._cache_order)
    end)
  end)

  describe('_build_source_map', function()
    it('should build lookup map from highlights grouped by 1-indexed line', function()
      local highlights = {
        { row = 0, col_start = 0, col_end = 5, hl_group = '@keyword' },
        { row = 0, col_start = 6, col_end = 10, hl_group = '@string' },
        { row = 2, col_start = 0, col_end = 3, hl_group = '@number' },
      }

      local map = annotator:_build_source_map(highlights)

      eq(2, #map[1])
      eq(0, map[1][1].col_start)
      eq(5, map[1][1].col_end)
      eq('@keyword', map[1][1].hl_group)
      eq(6, map[1][2].col_start)
      eq(10, map[1][2].col_end)
      eq('@string', map[1][2].hl_group)

      eq(1, #map[3])
      eq('@number', map[3][1].hl_group)

      eq(nil, map[2])
    end)

    it('should handle empty highlights', function()
      local map = annotator:_build_source_map({})
      eq({}, map)
    end)
  end)

  describe('_map_highlights', function()
    it('should map highlights from source line to target row', function()
      local result = {}
      local hl_map = {
        [5] = {
          { col_start = 0, col_end = 3, hl_group = '@keyword' },
          { col_start = 4, col_end = 10, hl_group = '@string' },
        },
      }

      annotator:_map_highlights(result, hl_map, 5, 10)

      eq(2, #result)
      eq(10, result[1].row)
      eq(0, result[1].col_start)
      eq(3, result[1].col_end)
      eq('@keyword', result[1].hl_group)
      eq(10, result[2].row)
      eq(4, result[2].col_start)
      eq(10, result[2].col_end)
    end)

    it('should handle col_end of -1', function()
      local result = {}
      local hl_map = {
        [1] = {
          { col_start = 0, col_end = -1, hl_group = '@comment' },
        },
      }

      annotator:_map_highlights(result, hl_map, 1, 0)

      eq(1, #result)
      eq(-1, result[1].col_end)
    end)

    it('should do nothing when source line has no highlights', function()
      local result = {}
      local hl_map = {}

      annotator:_map_highlights(result, hl_map, 5, 10)

      eq(0, #result)
    end)

    it('should pass through col_start and col_end unchanged', function()
      local result = {}
      local hl_map = {
        [1] = {
          { col_start = 2, col_end = 8, hl_group = '@variable' },
        },
      }

      annotator:_map_highlights(result, hl_map, 1, 3)

      eq(1, #result)
      eq(2, result[1].col_start)
      eq(8, result[1].col_end)
    end)
  end)
end)
