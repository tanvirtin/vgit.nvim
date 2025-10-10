local eq = assert.are.same
local TableGenerator = require('vgit.ui.TableGenerator')

describe('TableGenerator:', function()
  describe('constructor', function()
    it('should create a new instance with provided parameters', function()
      local labels = { 'Column 1', 'Column 2' }
      local rows = { { 'value1', 'value2' } }
      local spacing = 2
      local max_len = 50

      local generator = TableGenerator(labels, rows, spacing, max_len)

      eq(generator.labels, labels)
      eq(generator.rows, rows)
      eq(generator.spacing, spacing)
      eq(generator.max_len, max_len)
      assert.is_nil(generator.paddings)
    end)

    it('should be an Object instance', function()
      local Object = require('vgit.core.Object')
      local generator = TableGenerator({}, {}, 2, 50)

      assert.is_true(generator:is(TableGenerator))
      assert.is_true(generator:is(Object))
    end)
  end)

  describe('parse_item', function()
    it('should return text value for simple item', function()
      local generator = TableGenerator({}, {}, 2, 50)
      local item = { text = 'simple value' }

      local value, hl = generator:parse_item(item, 1)

      eq(value, 'simple value')
      assert.is_table(hl)
      assert.equals(#hl, 0)
    end)

    it('should prepend icon_before', function()
      local generator = TableGenerator({}, {}, 2, 50)
      local item = {
        text = 'value',
        icon_before = { icon = '●', hl = 'VGitComment' },
      }

      local value, hl = generator:parse_item(item, 1)

      eq(value, '● value')
      assert.equals(#hl, 1)
      eq(hl[1].hl, 'VGitComment')
      eq(hl[1].row, 1)
      assert.is_table(hl[1].range)
    end)

    it('should append icon_after', function()
      local generator = TableGenerator({}, {}, 2, 50)
      local item = {
        text = 'value',
        icon_after = { icon = '✓', hl = 'VGitSuccess' },
      }

      local value, hl = generator:parse_item(item, 1)

      assert.is_truthy(value:match('value ✓$'))
      assert.equals(#hl, 1)
      eq(hl[1].hl, 'VGitSuccess')
      eq(hl[1].row, 1)
    end)

    it('should handle both icon_before and icon_after', function()
      local generator = TableGenerator({}, {}, 2, 50)
      local item = {
        text = 'value',
        icon_before = { icon = '●', hl = 'VGitComment' },
        icon_after = { icon = '✓', hl = 'VGitSuccess' },
      }

      local value, hl = generator:parse_item(item, 1)

      assert.is_truthy(value:match('^● value ✓$'))
      assert.equals(#hl, 2)
      eq(hl[1].hl, 'VGitComment')
      eq(hl[2].hl, 'VGitSuccess')
    end)

    it('should set correct row for highlights', function()
      local generator = TableGenerator({}, {}, 2, 50)
      local item = {
        text = 'value',
        icon_before = { icon = '●', hl = 'VGitComment' },
      }

      local _, hl = generator:parse_item(item, 5)

      eq(hl[1].row, 5)
    end)
  end)

  describe('generate_paddings', function()
    it('should calculate paddings based on content width', function()
      local labels = { 'Name', 'Age' }
      local rows = {
        { 'Alice', '25' },
        { 'Bob', '30' },
      }
      local generator = TableGenerator(labels, rows, 2, 100)

      generator:generate_paddings()

      assert.is_table(generator.paddings)
      assert.equals(#generator.paddings, 2)
      -- Each padding includes: spacing + max_width + spacing
      assert.is_true(generator.paddings[1] >= 2 + 5 + 2) -- "Alice" = 5 chars
      assert.is_true(generator.paddings[2] >= 2 + 2 + 2) -- "30" = 2 chars
    end)

    it('should use max width across all rows', function()
      local labels = { 'Name' }
      local rows = {
        { 'Al' }, -- 2 chars
        { 'Alice' }, -- 5 chars
        { 'Alexander' }, -- 9 chars
      }
      local generator = TableGenerator(labels, rows, 1, 100)

      generator:generate_paddings()

      -- Padding formula: max(value + spacing, label + spacing) for each iteration
      -- Should end up with spacing + max_value_width + spacing
      assert.is_table(generator.paddings)
      assert.equals(#generator.paddings, 1)
      -- Verify it's at least the minimum expected (spacing + longest_value)
      assert.is_true(generator.paddings[1] >= 10, 'padding should accommodate "Alexander"')
    end)

    it('should respect max_len constraint', function()
      local labels = { 'Name' }
      local rows = { { 'VeryLongNameThatExceedsMaxLength' } }
      local max_len = 10
      local generator = TableGenerator(labels, rows, 2, max_len)

      generator:generate_paddings()

      -- Padding should be based on truncated length (max_len)
      assert.is_true(generator.paddings[1] <= 2 + max_len + 2)
    end)

    it('should assert equal column counts', function()
      local labels = { 'Col1', 'Col2' }
      local rows = { { 'value1' } } -- Missing second column
      local generator = TableGenerator(labels, rows, 2, 100)

      assert.has_error(function()
        generator:generate_paddings()
      end)
    end)

    it('should handle table items with icons', function()
      local labels = { 'Status' }
      local rows = {
        {
          {
            text = 'Modified',
            icon_before = { icon = '●', hl = 'VGitComment' },
          },
        },
      }
      local generator = TableGenerator(labels, rows, 2, 100)

      generator:generate_paddings()

      assert.is_table(generator.paddings)
      -- Should include icon + space + text
      assert.is_true(generator.paddings[1] >= 2 + 1 + 1 + 8 + 2) -- "● Modified"
    end)

    it('should return self for method chaining', function()
      local generator = TableGenerator({ 'Col' }, { { 'val' } }, 2, 100)

      local result = generator:generate_paddings()

      assert.equals(result, generator)
    end)
  end)

  describe('generate_labels', function()
    it('should generate a single row with label text', function()
      local labels = { 'Name', 'Age', 'City' }
      local rows = { { 'Alice', '25', 'NYC' } }
      local generator = TableGenerator(labels, rows, 2, 100)
      generator:generate_paddings()

      local label_row = generator:generate_labels()

      assert.is_table(label_row)
      assert.equals(#label_row, 1)
      assert.is_string(label_row[1])
      -- Labels should be present in the output
      assert.is_truthy(label_row[1]:match('Name'))
      assert.is_truthy(label_row[1]:match('Age'))
      assert.is_truthy(label_row[1]:match('City'))
    end)

    it('should include spacing at the start', function()
      local generator = TableGenerator({ 'Col' }, { { 'val' } }, 5, 100)
      generator:generate_paddings()

      local label_row = generator:generate_labels()

      -- Should start with spacing
      assert.is_truthy(label_row[1]:match('^     ')) -- 5 spaces
    end)

    it('should apply padding between columns', function()
      local generator = TableGenerator({ 'A', 'B' }, { { 'X', 'Y' } }, 2, 100)
      generator:generate_paddings()

      local label_row = generator:generate_labels()

      -- Should have multiple spaces between columns (padding)
      local spaces_count = 0
      for _ in label_row[1]:gmatch('  +') do
        spaces_count = spaces_count + 1
      end
      assert.is_true(spaces_count > 0, 'should have padding spaces')
    end)
  end)

  describe('generate_rows', function()
    it('should generate rows with correct count', function()
      local labels = { 'Col1', 'Col2' }
      local rows = {
        { 'val1', 'val2' },
        { 'val3', 'val4' },
        { 'val5', 'val6' },
      }
      local generator = TableGenerator(labels, rows, 2, 100)
      generator:generate_paddings()

      local lines, hls = generator:generate_rows()

      assert.is_table(lines)
      assert.is_table(hls)
      assert.equals(#lines, 3)
    end)

    it('should include row values in output', function()
      local labels = { 'Name' }
      local rows = {
        { 'Alice' },
        { 'Bob' },
      }
      local generator = TableGenerator(labels, rows, 2, 100)
      generator:generate_paddings()

      local lines, _ = generator:generate_rows()

      assert.is_truthy(lines[1]:match('Alice'))
      assert.is_truthy(lines[2]:match('Bob'))
    end)

    it('should handle simple string items', function()
      local labels = { 'Text' }
      local rows = { { 'simple text' } }
      local generator = TableGenerator(labels, rows, 2, 100)
      generator:generate_paddings()

      local lines, hls = generator:generate_rows()

      assert.equals(#lines, 1)
      assert.is_truthy(lines[1]:match('simple text'))
      assert.equals(#hls, 0)
    end)

    it('should handle table items with highlights', function()
      local labels = { 'Status' }
      local rows = {
        {
          {
            text = 'Modified',
            icon_before = { icon = '●', hl = 'VGitComment' },
          },
        },
      }
      local generator = TableGenerator(labels, rows, 2, 100)
      generator:generate_paddings()

      local lines, hls = generator:generate_rows()

      assert.equals(#lines, 1)
      assert.is_truthy(lines[1]:match('●'))
      assert.is_true(#hls > 0)
      eq(hls[1].hl, 'VGitComment')
    end)

    it('should adjust highlight ranges after generation', function()
      local labels = { 'Col' }
      local rows = {
        {
          {
            text = 'text',
            icon_before = { icon = '●', hl = 'VGitComment' },
          },
        },
      }
      local generator = TableGenerator(labels, rows, 2, 100)
      generator:generate_paddings()

      local _, hls = generator:generate_rows()

      -- Ranges should be adjusted by +1
      assert.is_number(hls[1].range.top)
      assert.is_number(hls[1].range.bot)
      assert.is_true(hls[1].range.top > 0)
      assert.is_true(hls[1].range.bot > 0)
    end)
  end)

  describe('generate', function()
    it('should return labels, rows, and highlights', function()
      local labels = { 'Name', 'Age' }
      local rows = {
        { 'Alice', '25' },
        { 'Bob', '30' },
      }
      local generator = TableGenerator(labels, rows, 2, 100)

      local label_lines, row_lines, hls = generator:generate()

      assert.is_table(label_lines)
      assert.is_table(row_lines)
      assert.is_table(hls)
      assert.equals(#label_lines, 1)
      assert.equals(#row_lines, 2)
    end)

    it('should generate complete table structure', function()
      local labels = { 'File', 'Status' }
      local rows = {
        { 'file1.lua', 'Modified' },
        { 'file2.lua', 'Added' },
      }
      local generator = TableGenerator(labels, rows, 2, 100)

      local label_lines, row_lines, _ = generator:generate()

      -- Verify labels
      assert.is_truthy(label_lines[1]:match('File'))
      assert.is_truthy(label_lines[1]:match('Status'))

      -- Verify rows
      assert.is_truthy(row_lines[1]:match('file1%.lua'))
      assert.is_truthy(row_lines[1]:match('Modified'))
      assert.is_truthy(row_lines[2]:match('file2%.lua'))
      assert.is_truthy(row_lines[2]:match('Added'))
    end)

    it('should handle single row', function()
      local labels = { 'Column' }
      local rows = { { 'value' } }
      local generator = TableGenerator(labels, rows, 2, 100)

      local label_lines, row_lines, hls = generator:generate()

      assert.equals(#label_lines, 1)
      assert.equals(#row_lines, 1)
      assert.equals(#hls, 0)
    end)

    it('should automatically call generate_paddings', function()
      local generator = TableGenerator({ 'Col' }, { { 'val' } }, 2, 100)

      -- paddings should be nil before generate
      assert.is_nil(generator.paddings)

      generator:generate()

      -- paddings should be set after generate
      assert.is_table(generator.paddings)
    end)
  end)

  describe('integration', function()
    it('should handle complete table with icons and highlights', function()
      local labels = { 'File', 'Status', 'Changes' }
      local rows = {
        {
          'src/main.lua',
          { text = 'Modified', icon_before = { icon = '●', hl = 'VGitModified' } },
          '+42 -10',
        },
        {
          'test/spec.lua',
          { text = 'Added', icon_before = { icon = '+', hl = 'VGitAdded' } },
          '+100 -0',
        },
      }
      local generator = TableGenerator(labels, rows, 2, 50)

      local label_lines, row_lines, hls = generator:generate()

      -- Verify structure
      assert.equals(#label_lines, 1)
      assert.equals(#row_lines, 2)
      assert.equals(#hls, 2) -- One for each icon

      -- Verify content
      assert.is_truthy(row_lines[1]:match('src/main%.lua'))
      assert.is_truthy(row_lines[1]:match('Modified'))
      assert.is_truthy(row_lines[2]:match('test/spec%.lua'))
      assert.is_truthy(row_lines[2]:match('Added'))

      -- Verify highlights
      eq(hls[1].hl, 'VGitModified')
      eq(hls[2].hl, 'VGitAdded')
    end)

    it('should properly align columns', function()
      local labels = { 'Short', 'Very Long Header' }
      local rows = {
        { 'A', 'X' },
        { 'BB', 'YY' },
        { 'CCC', 'ZZZ' },
      }
      local generator = TableGenerator(labels, rows, 2, 100)

      local label_lines, row_lines, _ = generator:generate()

      -- All rows should have similar length (aligned)
      local first_len = #row_lines[1]
      for i = 2, #row_lines do
        local len_diff = math.abs(#row_lines[i] - first_len)
        -- Allow small difference due to content length variation
        assert.is_true(len_diff <= 10, 'rows should have similar lengths')
      end
    end)
  end)
end)
