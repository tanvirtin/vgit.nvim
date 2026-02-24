local eq = assert.are.same

describe('git_diff:', function()
  local git_diff
  local mock_execute_result
  local mock_execute_error
  local original_qb

  local mock_qb = setmetatable({}, {
    __call = function(_, _reponame)
      return {
        diff = function(self)
          return self
        end,
        option = function(self, ...)
          return self
        end,
        refs = function(self, ...)
          return self
        end,
        execute = function()
          return mock_execute_result, mock_execute_error
        end,
      }
    end,
  })

  before_each(function()
    mock_execute_result = nil
    mock_execute_error = nil
    original_qb = package.loaded['vgit.git.GitQueryBuilder']
    package.loaded['vgit.git.GitQueryBuilder'] = mock_qb
    git_diff = require('vgit.git.git_diff')
  end)

  after_each(function()
    package.loaded['vgit.git.GitQueryBuilder'] = original_qb
  end)

  describe('range_patch_entries', function()
    it('should return empty table when execute returns empty result', function()
      mock_execute_result = {}
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(0, #entries)
    end)

    it('should return empty table when execute returns nil', function()
      mock_execute_result = nil
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(0, #entries)
    end)

    it('should return nil and error when execute errors', function()
      mock_execute_error = { 'fatal: not a git repository' }
      local entries, err = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      assert.is_nil(entries)
      eq({ 'fatal: not a git repository' }, err)
    end)

    it('should parse a single file with a single hunk', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        'index abc..def 100644',
        '--- a/foo.lua',
        '+++ b/foo.lua',
        '@@ -1,3 +1,3 @@',
        ' unchanged',
        '-old line',
        '+new line',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(2, #entries)
      eq('file_header', entries[1].type)
      eq('foo.lua', entries[1].filename)
      eq('hunk', entries[2].type)
      eq('@@ -1,3 +1,3 @@', entries[2].hunk.header)
      eq(3, #entries[2].hunk.diff)
      eq(' unchanged', entries[2].hunk.diff[1])
      eq('-old line', entries[2].hunk.diff[2])
      eq('+new line', entries[2].hunk.diff[3])
    end)

    it('should propagate filename and filetype to hunk entries', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -1,1 +1,1 @@',
        '-old',
        '+new',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq('foo.lua', entries[1].filename)
      eq('foo.lua', entries[2].filename)
      eq('lua', entries[1].filetype)
      eq('lua', entries[2].filetype)
    end)

    it('should parse multiple files', function()
      mock_execute_result = {
        'diff --git a/a.lua b/a.lua',
        '@@ -1,1 +1,1 @@',
        '-old a',
        '+new a',
        'diff --git a/b.lua b/b.lua',
        '@@ -2,1 +2,1 @@',
        '-old b',
        '+new b',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(4, #entries)
      eq('file_header', entries[1].type)
      eq('a.lua', entries[1].filename)
      eq('hunk', entries[2].type)
      eq('a.lua', entries[2].filename)
      eq('file_header', entries[3].type)
      eq('b.lua', entries[3].filename)
      eq('hunk', entries[4].type)
      eq('b.lua', entries[4].filename)
    end)

    it('should detect renames and set filename to "old -> new"', function()
      mock_execute_result = {
        'diff --git a/old.lua b/new.lua',
        'similarity index 90%',
        'rename from old.lua',
        'rename to new.lua',
        '--- a/old.lua',
        '+++ b/new.lua',
        '@@ -1,1 +1,1 @@',
        '-old',
        '+new',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(2, #entries)
      eq('file_header', entries[1].type)
      eq('old.lua -> new.lua', entries[1].filename)
      eq('hunk', entries[2].type)
      eq('new.lua', entries[2].filename)
    end)

    it('should drop file_header with no following hunk (binary file)', function()
      mock_execute_result = {
        'diff --git a/image.png b/image.png',
        'index abc..def 100644',
        'Binary files a/image.png and b/image.png differ',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(0, #entries)
    end)

    it('should keep text file and drop binary in the same diff', function()
      mock_execute_result = {
        'diff --git a/script.lua b/script.lua',
        '@@ -1,1 +1,1 @@',
        '-old',
        '+new',
        'diff --git a/image.png b/image.png',
        'Binary files a/image.png and b/image.png differ',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(2, #entries)
      eq('file_header', entries[1].type)
      eq('script.lua', entries[1].filename)
      eq('hunk', entries[2].type)
    end)

    it('should drop empty hunks (hunk header with no +/-/space lines)', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -1,0 +1,0 @@',
        '@@ -5,2 +5,2 @@',
        '-real',
        '+line',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(2, #entries)
      eq('file_header', entries[1].type)
      eq('hunk', entries[2].type)
      eq(2, #entries[2].hunk.diff)
    end)

    it('should capture hunk header with trailing function context', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -10,3 +10,3 @@ function MyFunc()',
        '-old',
        '+new',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq('@@ -10,3 +10,3 @@ function MyFunc()', entries[2].hunk.header)
    end)

    it('should handle multiple hunks per file', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -1,2 +1,2 @@',
        '-old1',
        '+new1',
        '@@ -10,2 +10,2 @@',
        '-old2',
        '+new2',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(3, #entries)
      eq('file_header', entries[1].type)
      eq('hunk', entries[2].type)
      eq('@@ -1,2 +1,2 @@', entries[2].hunk.header)
      eq('hunk', entries[3].type)
      eq('@@ -10,2 +10,2 @@', entries[3].hunk.header)
    end)

    it('should skip index, --- and +++ lines outside of diff content', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        'index abc..def 100644',
        '--- a/foo.lua',
        '+++ b/foo.lua',
        '@@ -1,2 +1,2 @@',
        '-old',
        '+new',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(2, #entries)
      eq(2, #entries[2].hunk.diff)
      eq('-old', entries[2].hunk.diff[1])
      eq('+new', entries[2].hunk.diff[2])
    end)
  end)

  describe('hunk top/bot extraction from header', function()
    it('should extract top=5 and bot=8 from @@ -1,3 +5,4 @@', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -1,3 +5,4 @@',
        '-a',
        '+b',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(2, #entries)
      eq(5, entries[2].hunk.top)
      eq(8, entries[2].hunk.bot)
    end)

    it('should extract top=1 and bot=1 from @@ -1,1 +1,1 @@', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -1,1 +1,1 @@',
        '-old',
        '+new',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(1, entries[2].hunk.top)
      eq(1, entries[2].hunk.bot)
    end)

    it('should extract top=1 and bot=1 from @@ -0,0 +1 @@ (no count)', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -0,0 +1 @@',
        '+new file',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(1, entries[2].hunk.top)
      eq(1, entries[2].hunk.bot)
    end)

    it('should extract top=10 and bot=12 from @@ -10,3 +10,3 @@ function MyFunc()', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -10,3 +10,3 @@ function MyFunc()',
        '-old',
        '+new',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(10, entries[2].hunk.top)
      eq(12, entries[2].hunk.bot)
    end)

    it('should handle bot = top for single-line hunk @@ -5,1 +5,1 @@', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -5,1 +5,1 @@',
        '-x',
        '+y',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      eq(5, entries[2].hunk.top)
      eq(5, entries[2].hunk.bot)
    end)

    it('should store top/bot on all hunks in a multi-hunk file', function()
      mock_execute_result = {
        'diff --git a/foo.lua b/foo.lua',
        '@@ -1,2 +1,2 @@',
        '-a',
        '+b',
        '@@ -10,3 +10,3 @@',
        '-c',
        '+d',
      }
      local entries = git_diff.range_patch_entries('/repo', 'HEAD^', 'HEAD')
      -- entries[1]=file_header, entries[2]=hunk1, entries[3]=hunk2
      eq(1, entries[2].hunk.top)
      eq(2, entries[2].hunk.bot)
      eq(10, entries[3].hunk.top)
      eq(12, entries[3].hunk.bot)
    end)
  end)

  describe('staged_patch_entries', function()
    it('should return empty table when execute returns empty result', function()
      mock_execute_result = {}
      local entries = git_diff.staged_patch_entries('/repo')
      eq(0, #entries)
    end)

    it('should return empty table when execute returns nil', function()
      mock_execute_result = nil
      local entries = git_diff.staged_patch_entries('/repo')
      eq(0, #entries)
    end)

    it('should return nil and error when execute errors', function()
      mock_execute_error = { 'fatal: not a git repository' }
      local entries, err = git_diff.staged_patch_entries('/repo')
      assert.is_nil(entries)
      eq({ 'fatal: not a git repository' }, err)
    end)

    it('should parse valid diff output into patch entries', function()
      mock_execute_result = {
        'diff --git a/staged.lua b/staged.lua',
        '@@ -1,1 +1,1 @@',
        '-old staged',
        '+new staged',
      }
      local entries = git_diff.staged_patch_entries('/repo')
      eq(2, #entries)
      eq('file_header', entries[1].type)
      eq('staged.lua', entries[1].filename)
      eq('hunk', entries[2].type)
      eq('-old staged', entries[2].hunk.diff[1])
      eq('+new staged', entries[2].hunk.diff[2])
    end)

    it('should call option(cached) and refs(HEAD)', function()
      local options_called = {}
      local refs_called = {}
      local tracked_qb = setmetatable({}, {
        __call = function(_, _reponame)
          return {
            diff = function(s)
              return s
            end,
            option = function(s, key, val)
              table.insert(options_called, { key = key, val = val })
              return s
            end,
            refs = function(s, ...)
              refs_called = { ... }
              return s
            end,
            execute = function()
              return {}, nil
            end,
          }
        end,
      })

      package.loaded['vgit.git.GitQueryBuilder'] = tracked_qb
      git_diff = require('vgit.git.git_diff')

      git_diff.staged_patch_entries('/repo')

      local cached_found = false
      for _, opt in ipairs(options_called) do
        if opt.key == 'cached' then cached_found = true end
      end
      assert.is_true(cached_found)
      eq('HEAD', refs_called[1])

      package.loaded['vgit.git.GitQueryBuilder'] = mock_qb
    end)

    it('should include top and bot in hunk entries', function()
      mock_execute_result = {
        'diff --git a/a.lua b/a.lua',
        '@@ -3,2 +3,2 @@',
        '-old',
        '+new',
      }
      local entries = git_diff.staged_patch_entries('/repo')
      eq(3, entries[2].hunk.top)
      eq(4, entries[2].hunk.bot)
    end)
  end)

  describe('unstaged_patch_entries', function()
    it('should return empty table when execute returns empty result', function()
      mock_execute_result = {}
      local entries = git_diff.unstaged_patch_entries('/repo')
      eq(0, #entries)
    end)

    it('should return empty table when execute returns nil', function()
      mock_execute_result = nil
      local entries = git_diff.unstaged_patch_entries('/repo')
      eq(0, #entries)
    end)

    it('should return nil and error when execute errors', function()
      mock_execute_error = { 'fatal: not a git repository' }
      local entries, err = git_diff.unstaged_patch_entries('/repo')
      assert.is_nil(entries)
      eq({ 'fatal: not a git repository' }, err)
    end)

    it('should parse valid diff output into patch entries', function()
      mock_execute_result = {
        'diff --git a/unstaged.lua b/unstaged.lua',
        '@@ -2,2 +2,2 @@',
        '-old unstaged',
        '+new unstaged',
      }
      local entries = git_diff.unstaged_patch_entries('/repo')
      eq(2, #entries)
      eq('file_header', entries[1].type)
      eq('unstaged.lua', entries[1].filename)
      eq('hunk', entries[2].type)
      eq('-old unstaged', entries[2].hunk.diff[1])
    end)

    it('should NOT call refs() (no HEAD arg)', function()
      local refs_called = false
      local tracked_qb = setmetatable({}, {
        __call = function(_, _reponame)
          return {
            diff = function(s)
              return s
            end,
            option = function(s, _key, _val)
              return s
            end,
            refs = function(s, ...)
              refs_called = true
              return s
            end,
            execute = function()
              return {}, nil
            end,
          }
        end,
      })

      package.loaded['vgit.git.GitQueryBuilder'] = tracked_qb
      git_diff = require('vgit.git.git_diff')

      git_diff.unstaged_patch_entries('/repo')
      assert.is_false(refs_called)

      package.loaded['vgit.git.GitQueryBuilder'] = mock_qb
    end)

    it('should include top and bot in hunk entries', function()
      mock_execute_result = {
        'diff --git a/b.lua b/b.lua',
        '@@ -7,4 +7,4 @@',
        '-old',
        '+new',
      }
      local entries = git_diff.unstaged_patch_entries('/repo')
      eq(7, entries[2].hunk.top)
      eq(10, entries[2].hunk.bot)
    end)
  end)
end)
