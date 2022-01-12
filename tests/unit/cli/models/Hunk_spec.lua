local Hunk = require('vgit.cli.models.Hunk')

local describe = describe
local it = it
local before_each = before_each
local after_each = after_each
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
      eq(Hunk:new(headers['add']), {
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
      eq(Hunk:new(headers['remove']), {
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
      eq(Hunk:new(headers['change']), {
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
      eq(Hunk:new(headers['invalid']), {
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
      eq(Hunk:new(headers['invalid_zero']), {
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
