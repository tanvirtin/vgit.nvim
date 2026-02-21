local statusline_state = require('vgit.core.statusline_state')

local eq = assert.are.same

describe('statusline_state:', function()
  before_each(function()
    statusline_state.reset()
    vim.g.vgit_hunk_index = nil
    vim.g.vgit_hunk_count = nil
    vim.g.vgit_added = nil
    vim.g.vgit_removed = nil
    vim.g.vgit_changed = nil
    vim.g.vgit_branch = nil
  end)

  describe('set_hunk and get_hunk', function()
    it('should set and get hunk state', function()
      statusline_state.set_hunk(2, 5)
      local hunk = statusline_state.get_hunk()
      eq(2, hunk.index)
      eq(5, hunk.count)
    end)

    it('should return nil when hunk not set', function()
      local hunk = statusline_state.get_hunk()
      eq(nil, hunk)
    end)

    it('should set vim globals', function()
      statusline_state.set_hunk(3, 10)
      eq(3, vim.g.vgit_hunk_index)
      eq(10, vim.g.vgit_hunk_count)
    end)
  end)

  describe('set_diff_stats and get_diff_stats', function()
    it('should set and get diff stats', function()
      statusline_state.set_diff_stats({ added = 10, removed = 5, changed = 3 })
      local stats = statusline_state.get_diff_stats()
      eq(10, stats.added)
      eq(5, stats.removed)
      eq(3, stats.changed)
    end)

    it('should return nil when diff stats not set', function()
      local stats = statusline_state.get_diff_stats()
      eq(nil, stats)
    end)

    it('should set vim globals', function()
      statusline_state.set_diff_stats({ added = 1, removed = 2, changed = 3 })
      eq(1, vim.g.vgit_added)
      eq(2, vim.g.vgit_removed)
      eq(3, vim.g.vgit_changed)
    end)

    it('should clear vim globals when stats is nil', function()
      statusline_state.set_diff_stats({ added = 1 })
      statusline_state.set_diff_stats(nil)
      eq(nil, vim.g.vgit_added)
      eq(nil, vim.g.vgit_removed)
      eq(nil, vim.g.vgit_changed)
    end)
  end)

  describe('set_branch and get_branch', function()
    it('should set and get branch', function()
      statusline_state.set_branch('main')
      eq('main', statusline_state.get_branch())
    end)

    it('should return nil when branch not set', function()
      eq(nil, statusline_state.get_branch())
    end)

    it('should set vim global', function()
      statusline_state.set_branch('develop')
      eq('develop', vim.g.vgit_branch)
    end)
  end)

  describe('reset', function()
    it('should clear all state', function()
      statusline_state.set_hunk(1, 5)
      statusline_state.set_diff_stats({ added = 10 })
      statusline_state.set_branch('main')

      statusline_state.reset()

      eq(nil, statusline_state.get_hunk())
      eq(nil, statusline_state.get_diff_stats())
      eq(nil, statusline_state.get_branch())
    end)

    it('should clear all vim globals', function()
      vim.g.vgit_hunk_index = 1
      vim.g.vgit_hunk_count = 5
      vim.g.vgit_added = 10
      vim.g.vgit_removed = 5
      vim.g.vgit_changed = 3
      vim.g.vgit_branch = 'main'

      statusline_state.reset()

      eq(nil, vim.g.vgit_hunk_index)
      eq(nil, vim.g.vgit_hunk_count)
      eq(nil, vim.g.vgit_added)
      eq(nil, vim.g.vgit_removed)
      eq(nil, vim.g.vgit_changed)
      eq(nil, vim.g.vgit_branch)
    end)
  end)

  describe('get_hunk edge cases', function()
    it('should return nil if only index is set', function()
      statusline_state.set_hunk(2, nil)
      eq(nil, statusline_state.get_hunk())
    end)

    it('should return nil if only count is set', function()
      statusline_state.set_hunk(nil, 5)
      eq(nil, statusline_state.get_hunk())
    end)
  end)
end)
