local Hunk = require('vgit.git.cli.models.Hunk')

local eq = assert.are.same

describe('Hunk:', function()
  describe('new', function()
    it('should create a new Hunk object', function()
      local headers = {
        add = '@@ -17,0 +18,15 @@ foo bar',
        remove = '@@ -9,9 +8,0 @@ @@ foo bar',
        change = '@@ -10,7 +10,7 @@ foo bar',
        invalid = '@@ --10,-1 +-10,-7 @@ foo bar',
        invalid_zero = '@@ -0,0 +0,0 @@ foo bar',
      }

      eq(Hunk(headers['add']), {
        header = '@@ -17,0 +18,15 @@ foo bar',
        diff = {},
        top = 18,
        bot = 32,
        type = 'add',
        stat = {
          added = 0,
          removed = 0,
        },
      })
      eq(Hunk(headers['remove']), {
        header = '@@ -9,9 +8,0 @@ @@ foo bar',
        diff = {},
        top = 8,
        bot = 8,
        type = 'remove',
        stat = {
          added = 0,
          removed = 0,
        },
      })
      eq(Hunk(headers['change']), {
        header = '@@ -10,7 +10,7 @@ foo bar',
        diff = {},
        top = 10,
        bot = 16,
        type = 'change',
        stat = {
          added = 0,
          removed = 0,
        },
      })
      eq(Hunk(headers['invalid']), {
        header = '@@ --10,-1 +-10,-7 @@ foo bar',
        diff = {},
        top = -10,
        bot = -18,
        type = 'change',
        stat = {
          added = 0,
          removed = 0,
        },
      })
      eq(Hunk(headers['invalid_zero']), {
        header = '@@ -0,0 +0,0 @@ foo bar',
        diff = {},
        top = 0,
        bot = 0,
        type = 'remove',
        stat = {
          added = 0,
          removed = 0,
        },
      })
    end)
  end)
end)
