local conflict_service = require('vgit.services.conflict')

describe('conflict_service:', function()
  it('should be able to parse conflicts successfully', function()
    local conflicts = conflict_service:parse({
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
      current = {
        start = 1,
        finish = 3,
      },
      ancestor = {
        start = 4,
        finish = 5,
      },
      middle = {
        start = 6,
        finish = 7,
      },
      incoming = {
        start = 7,
        finish = 8,
      },
    }
    local expected_conflicts = { expected_conflict }

    assert.are.same(conflicts, expected_conflicts)
  end)
end)
