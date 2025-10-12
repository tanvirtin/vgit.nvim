local GitHunk = require('vgit.git.GitHunk')

local eq = assert.are.same

describe('GitHunk:', function()
  describe('constructor', function()
    it('should create a new add-type hunk', function()
      local hunk = GitHunk('@@ -17,0 +18,15 @@ foo bar')

      assert.is_not_nil(hunk, 'Hunk should be created')
      assert.equals('@@ -17,0 +18,15 @@ foo bar', hunk.header, 'Header should match')
      assert.is_table(hunk.diff, 'Diff should be a table')
      assert.equals(0, #hunk.diff, 'Diff should be empty initially')
      assert.equals(18, hunk.top, 'Top line should be 18')
      assert.equals(32, hunk.bot, 'Bottom line should be 32 (18 + 15 - 1)')
      assert.equals('add', hunk.type, 'Type should be add')
      assert.is_table(hunk.stat, 'Stat should be a table')
      assert.equals(0, hunk.stat.added, 'Added count should be 0 initially')
      assert.equals(0, hunk.stat.removed, 'Removed count should be 0 initially')
    end)

    it('should create a new remove-type hunk', function()
      local hunk = GitHunk('@@ -9,9 +8,0 @@ @@ foo bar')

      assert.is_not_nil(hunk, 'Hunk should be created')
      assert.equals('@@ -9,9 +8,0 @@ @@ foo bar', hunk.header, 'Header should match')
      assert.equals(8, hunk.top, 'Top line should be 8')
      assert.equals(8, hunk.bot, 'Bottom line should be 8 (special case for remove)')
      assert.equals('remove', hunk.type, 'Type should be remove when current size is 0')
    end)

    it('should create a new change-type hunk', function()
      local hunk = GitHunk('@@ -10,7 +10,7 @@ foo bar')

      assert.is_not_nil(hunk, 'Hunk should be created')
      assert.equals('@@ -10,7 +10,7 @@ foo bar', hunk.header, 'Header should match')
      assert.equals(10, hunk.top, 'Top line should be 10')
      assert.equals(16, hunk.bot, 'Bottom line should be 16 (10 + 7 - 1)')
      assert.equals('change', hunk.type, 'Type should be change')
    end)

    it('should handle hunk with negative values', function()
      local hunk = GitHunk('@@ --10,-1 +-10,-7 @@ foo bar')

      assert.is_not_nil(hunk, 'Hunk should be created even with invalid values')
      assert.equals(-10, hunk.top, 'Should parse negative top')
      assert.equals(-18, hunk.bot, 'Should calculate bot from negative values')
    end)

    it('should handle zero values', function()
      local hunk = GitHunk('@@ -0,0 +0,0 @@ foo bar')

      assert.is_not_nil(hunk, 'Hunk should be created with zero values')
      assert.equals(0, hunk.top, 'Top should be 0')
      assert.equals(0, hunk.bot, 'Bot should be 0')
      assert.equals('remove', hunk.type, 'Type should be remove for 0,0')
    end)

    it('should create empty hunk when no header provided', function()
      local hunk = GitHunk()

      assert.is_not_nil(hunk, 'Hunk should be created')
      assert.is_nil(hunk.header, 'Header should be nil')
      assert.is_nil(hunk.top, 'Top should be nil')
      assert.is_nil(hunk.bot, 'Bot should be nil')
      assert.is_nil(hunk.type, 'Type should be nil')
      assert.is_table(hunk.diff, 'Diff should still be a table')
      assert.equals(0, #hunk.diff, 'Diff should be empty')
    end)

    it('should accept header as array', function()
      -- Header can be provided as {previous, current} arrays
      local hunk = GitHunk({ { 10, 5 }, { 10, 7 } })

      assert.is_not_nil(hunk, 'Hunk should be created from array')
      assert.equals('@@ -10,5 +10,7 @@', hunk.header, 'Header should be generated')
      assert.equals(10, hunk.top, 'Top should be 10')
      assert.equals(16, hunk.bot, 'Bot should be 16 (10 + 7 - 1)')
      assert.equals('change', hunk.type, 'Type should be change')
    end)
  end)

  describe('parse_header', function()
    it('should parse add-type header correctly', function()
      local hunk = GitHunk('@@ -17,0 +18,15 @@ context')
      local previous, current = hunk:parse_header()

      assert.is_table(previous, 'Previous should be a table')
      assert.is_table(current, 'Current should be a table')
      assert.equals(17, previous[1], 'Previous line number should be 17')
      assert.equals(0, previous[2], 'Previous line count should be 0')
      assert.equals(18, current[1], 'Current line number should be 18')
      assert.equals(15, current[2], 'Current line count should be 15')
    end)

    it('should parse change-type header correctly', function()
      local hunk = GitHunk('@@ -10,7 +10,7 @@ foo')
      local previous, current = hunk:parse_header()

      assert.equals(10, previous[1], 'Previous line number should be 10')
      assert.equals(7, previous[2], 'Previous line count should be 7')
      assert.equals(10, current[1], 'Current line number should be 10')
      assert.equals(7, current[2], 'Current line count should be 7')
    end)

    it('should default line count to 1 when omitted', function()
      local hunk = GitHunk('@@ -5 +5 @@')
      local previous, current = hunk:parse_header()

      assert.equals(5, previous[1], 'Previous line number should be 5')
      assert.equals(1, previous[2], 'Previous line count should default to 1')
      assert.equals(5, current[1], 'Current line number should be 5')
      assert.equals(1, current[2], 'Current line count should default to 1')
    end)

    it('should parse header with context', function()
      local hunk = GitHunk('@@ -100,5 +200,10 @@ function foo()')
      local previous, current = hunk:parse_header()

      assert.equals(100, previous[1], 'Previous line number should be 100')
      assert.equals(5, previous[2], 'Previous line count should be 5')
      assert.equals(200, current[1], 'Current line number should be 200')
      assert.equals(10, current[2], 'Current line count should be 10')
    end)
  end)

  describe('generate_header', function()
    it('should generate header from line numbers', function()
      local hunk = GitHunk()
      local header = hunk:generate_header({ 10, 5 }, { 10, 7 })

      assert.equals('@@ -10,5 +10,7 @@', header, 'Header should be formatted correctly')
    end)

    it('should generate header for add-type hunk', function()
      local hunk = GitHunk()
      local header = hunk:generate_header({ 17, 0 }, { 18, 15 })

      assert.equals('@@ -17,0 +18,15 @@', header, 'Add header should be formatted correctly')
    end)

    it('should generate header for remove-type hunk', function()
      local hunk = GitHunk()
      local header = hunk:generate_header({ 9, 9 }, { 8, 0 })

      assert.equals('@@ -9,9 +8,0 @@', header, 'Remove header should be formatted correctly')
    end)

    it('should generate header with large line numbers', function()
      local hunk = GitHunk()
      local header = hunk:generate_header({ 1000, 50 }, { 2000, 100 })

      assert.equals('@@ -1000,50 +2000,100 @@', header, 'Should handle large numbers')
    end)
  end)

  describe('parse_diff', function()
    it('should parse diff lines into removed and added', function()
      local hunk = GitHunk('@@ -5,3 +5,3 @@')
      hunk.diff = {
        ' context line',
        '-removed line',
        '+added line',
        ' another context',
      }

      local removed, added = hunk:parse_diff()

      assert.is_table(removed, 'Removed should be a table')
      assert.is_table(added, 'Added should be a table')
      assert.equals(1, #removed, 'Should have 1 removed line')
      assert.equals(1, #added, 'Should have 1 added line')
      assert.equals('removed line', removed[1], 'Removed line content should match')
      assert.equals('added line', added[1], 'Added line content should match')
    end)

    it('should parse multiple additions and removals', function()
      local hunk = GitHunk('@@ -10,5 +10,5 @@')
      hunk.diff = {
        '-old line 1',
        '-old line 2',
        '-old line 3',
        '+new line 1',
        '+new line 2',
        ' context',
      }

      local removed, added = hunk:parse_diff()

      assert.equals(3, #removed, 'Should have 3 removed lines')
      assert.equals(2, #added, 'Should have 2 added lines')
      assert.equals('old line 1', removed[1], 'First removed line should match')
      assert.equals('old line 3', removed[3], 'Third removed line should match')
      assert.equals('new line 1', added[1], 'First added line should match')
      assert.equals('new line 2', added[2], 'Second added line should match')
    end)

    it('should handle diff with only additions', function()
      local hunk = GitHunk('@@ -5,0 +5,3 @@')
      hunk.diff = {
        '+line 1',
        '+line 2',
        '+line 3',
      }

      local removed, added = hunk:parse_diff()

      assert.equals(0, #removed, 'Should have no removed lines')
      assert.equals(3, #added, 'Should have 3 added lines')
    end)

    it('should handle diff with only removals', function()
      local hunk = GitHunk('@@ -5,3 +5,0 @@')
      hunk.diff = {
        '-line 1',
        '-line 2',
        '-line 3',
      }

      local removed, added = hunk:parse_diff()

      assert.equals(3, #removed, 'Should have 3 removed lines')
      assert.equals(0, #added, 'Should have no added lines')
    end)

    it('should handle empty diff', function()
      local hunk = GitHunk('@@ -5,0 +5,0 @@')
      hunk.diff = {}

      local removed, added = hunk:parse_diff()

      assert.equals(0, #removed, 'Should have no removed lines')
      assert.equals(0, #added, 'Should have no added lines')
    end)
  end)

  describe('push', function()
    it('should add line to diff and update stats', function()
      local hunk = GitHunk('@@ -5,1 +5,1 @@')

      assert.equals(0, #hunk.diff, 'Diff should be empty initially')
      assert.equals(0, hunk.stat.added, 'Added count should be 0 initially')

      local result = hunk:push('+new line')

      assert.equals(hunk, result, 'Should return self for chaining')
      assert.equals(1, #hunk.diff, 'Diff should have 1 line')
      assert.equals('+new line', hunk.diff[1], 'Line content should match')
      assert.equals(1, hunk.stat.added, 'Added count should be 1')
      assert.equals(0, hunk.stat.removed, 'Removed count should still be 0')
    end)

    it('should track removed lines', function()
      local hunk = GitHunk('@@ -5,1 +5,1 @@')

      hunk:push('-removed line')

      assert.equals(1, #hunk.diff, 'Diff should have 1 line')
      assert.equals(0, hunk.stat.added, 'Added count should be 0')
      assert.equals(1, hunk.stat.removed, 'Removed count should be 1')
    end)

    it('should not track context lines in stats', function()
      local hunk = GitHunk('@@ -5,3 +5,3 @@')

      hunk:push(' context line')

      assert.equals(1, #hunk.diff, 'Diff should have 1 line')
      assert.equals(0, hunk.stat.added, 'Added count should be 0')
      assert.equals(0, hunk.stat.removed, 'Removed count should be 0')
    end)

    it('should support method chaining', function()
      local hunk = GitHunk('@@ -5,5 +5,5 @@')

      hunk:push(' context'):push('-old'):push('+new'):push(' context2')

      assert.equals(4, #hunk.diff, 'Should have 4 lines')
      assert.equals(1, hunk.stat.added, 'Should have 1 added line')
      assert.equals(1, hunk.stat.removed, 'Should have 1 removed line')
    end)

    it('should handle multiple additions and removals', function()
      local hunk = GitHunk('@@ -10,10 +10,10 @@')

      for i = 1, 5 do
        hunk:push('-removed ' .. i)
      end
      for i = 1, 7 do
        hunk:push('+added ' .. i)
      end

      assert.equals(12, #hunk.diff, 'Should have 12 lines total')
      assert.equals(7, hunk.stat.added, 'Should have 7 added lines')
      assert.equals(5, hunk.stat.removed, 'Should have 5 removed lines')
    end)
  end)

  describe('integration', function()
    it('should build a complete hunk with push and parse', function()
      local hunk = GitHunk('@@ -5,3 +5,4 @@ function foo()')

      hunk
        :push(' function foo()')
        :push('-  old implementation')
        :push('+  new implementation')
        :push('+  extra line')
        :push(' end')

      assert.equals(5, #hunk.diff, 'Should have 5 lines in diff')
      assert.equals(2, hunk.stat.added, 'Should have 2 added lines')
      assert.equals(1, hunk.stat.removed, 'Should have 1 removed line')

      local removed, added = hunk:parse_diff()
      assert.equals(1, #removed, 'Should parse 1 removed line')
      assert.equals(2, #added, 'Should parse 2 added lines')
      assert.equals('  old implementation', removed[1], 'Removed content should match')
      assert.equals('  new implementation', added[1], 'First added content should match')
      assert.equals('  extra line', added[2], 'Second added content should match')
    end)
  end)
end)
