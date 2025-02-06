local git_conflict = require('vgit.libgit2.git_conflict')

describe('git_conflict:', function()
  describe('parse', function()
    it('should be able to parse conflicts successfully', function()
      local conflicts = git_conflict.parse({
        '<<<<<<< HEAD',
        'local foo = 1',
        'print(foo)',
        '||||||| 1f5d944',
        'local foo = 2',
        '=======',
        'local foo = 3',
        '>>>>>>> incoming_branch',
      })

      local expected_conflict = {
        current = { top = 1, bot = 3 },
        ancestor = { top = 4, bot = 5 },
        middle = { top = 6, bot = 7 },
        incoming = { top = 7, bot = 8 },
      }
      local expected_conflicts = { expected_conflict }

      assert.are.same(conflicts, expected_conflicts)
    end)
  end)
end)
