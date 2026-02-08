local eq = assert.are.same

describe('GitFile:generate_status', function()
  local GitFile_generate_status

  before_each(function()
    -- Create a minimal object that has the generate_status method
    -- without requiring the full GitFile constructor (which needs git)
    local GitFile = require('vgit.git.GitFile')
    GitFile_generate_status = function(hunks)
      local obj = { state = { hunks = hunks } }
      setmetatable(obj, { __index = GitFile })
      return obj:generate_status()
    end
  end)

  it('should return zeros for empty hunks', function()
    local status = GitFile_generate_status({})

    eq({ added = 0, changed = 0, removed = 0 }, status)
  end)

  it('should return zeros for nil hunks', function()
    local status = GitFile_generate_status(nil)

    eq({ added = 0, changed = 0, removed = 0 }, status)
  end)

  it('should count pure additions', function()
    local hunks = {
      { stat = { added = 5, removed = 0 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 5, changed = 0, removed = 0 }, status)
  end)

  it('should count pure removals', function()
    local hunks = {
      { stat = { added = 0, removed = 3 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 0, removed = 3 }, status)
  end)

  it('should count changes as min(added, removed)', function()
    -- When added=3, removed=2: changed=min(3,2)=2, net_added=3-2=1, net_removed=0
    local hunks = {
      { stat = { added = 3, removed = 2 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 1, changed = 2, removed = 0 }, status)
  end)

  it('should count changes when removed > added', function()
    -- When added=2, removed=5: changed=min(2,5)=2, net_added=0, net_removed=3
    local hunks = {
      { stat = { added = 2, removed = 5 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 2, removed = 3 }, status)
  end)

  it('should count equal added and removed as all changed', function()
    -- When added=4, removed=4: changed=4, net_added=0, net_removed=0
    local hunks = {
      { stat = { added = 4, removed = 4 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 4, removed = 0 }, status)
  end)

  it('should sum across multiple hunks', function()
    local hunks = {
      { stat = { added = 5, removed = 0 } }, -- +5 added
      { stat = { added = 0, removed = 3 } }, -- +3 removed
      { stat = { added = 3, removed = 2 } }, -- +1 added, +2 changed
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 6, changed = 2, removed = 3 }, status)
  end)

  it('should handle multiple change hunks', function()
    local hunks = {
      { stat = { added = 2, removed = 1 } }, -- changed=1, added=1
      { stat = { added = 1, removed = 3 } }, -- changed=1, removed=2
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 1, changed = 2, removed = 2 }, status)
  end)

  it('should handle single line add', function()
    local hunks = {
      { stat = { added = 1, removed = 0 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 1, changed = 0, removed = 0 }, status)
  end)

  it('should handle single line remove', function()
    local hunks = {
      { stat = { added = 0, removed = 1 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 0, removed = 1 }, status)
  end)

  it('should handle single line change', function()
    local hunks = {
      { stat = { added = 1, removed = 1 } },
    }
    local status = GitFile_generate_status(hunks)

    eq({ added = 0, changed = 1, removed = 0 }, status)
  end)

  it('should handle large numbers', function()
    local hunks = {
      { stat = { added = 100, removed = 50 } },
      { stat = { added = 200, removed = 300 } },
    }
    local status = GitFile_generate_status(hunks)

    -- Hunk 1: changed=50, added=50, removed=0
    -- Hunk 2: changed=200, added=0, removed=100
    eq({ added = 50, changed = 250, removed = 100 }, status)
  end)
end)
