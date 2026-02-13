local eq = assert.are.same

describe('ProjectDiffView:', function()
  local ProjectDiffView

  before_each(function()
    ProjectDiffView = require('vgit.features.screens.ProjectDiffView')
  end)

  describe('_build_split_patch_entries', function()
    it('should split file_header entries identically to both sides', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'file_header',
          filename = 'test.lua',
          filetype = 'lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(1, #prev)
      eq(1, #curr)
      eq('file_header', prev[1].type)
      eq('file_header', curr[1].type)
      eq('test.lua', prev[1].filename)
      eq('test.lua', curr[1].filename)
    end)

    it('should split hunk with added lines', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,1 +1,2 @@',
            diff = {
              ' context',
              '+added',
            },
            top = 1,
            bot = 2,
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(1, #prev)
      eq(1, #curr)

      -- Previous side: context + space placeholder for added line
      eq(2, #prev[1].hunk.diff)
      eq(' context', prev[1].hunk.diff[1])
      eq(' ', prev[1].hunk.diff[2]) -- placeholder

      -- Current side: context + added line
      eq(2, #curr[1].hunk.diff)
      eq(' context', curr[1].hunk.diff[1])
      eq('+added', curr[1].hunk.diff[2])
    end)

    it('should split hunk with removed lines', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,2 +1,1 @@',
            diff = {
              ' context',
              '-removed',
            },
            top = 1,
            bot = 2,
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      -- Previous side: context + removed line
      eq(' context', prev[1].hunk.diff[1])
      eq('-removed', prev[1].hunk.diff[2])

      -- Current side: context + space placeholder
      eq(' context', curr[1].hunk.diff[1])
      eq(' ', curr[1].hunk.diff[2]) -- placeholder
    end)

    it('should split hunk with mixed changes', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -1,3 +1,3 @@',
            diff = {
              ' context1',
              '-old_line',
              '+new_line',
              ' context2',
            },
            top = 1,
            bot = 4,
          },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(4, #prev[1].hunk.diff)
      eq(4, #curr[1].hunk.diff)

      -- Context lines identical
      eq(' context1', prev[1].hunk.diff[1])
      eq(' context1', curr[1].hunk.diff[1])
      eq(' context2', prev[1].hunk.diff[4])
      eq(' context2', curr[1].hunk.diff[4])

      -- Removed line: present in prev, space in curr
      eq('-old_line', prev[1].hunk.diff[2])
      eq(' ', curr[1].hunk.diff[2])

      -- Added line: space in prev, present in curr
      eq(' ', prev[1].hunk.diff[3])
      eq('+new_line', curr[1].hunk.diff[3])
    end)

    it('should preserve hunk metadata', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = {
            header = '@@ -5,2 +5,2 @@',
            diff = { '-a', '+b' },
            top = 5,
            bot = 6,
          },
          filetype = 'python',
          filename = 'app.py',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq('@@ -5,2 +5,2 @@', prev[1].hunk.header)
      eq('@@ -5,2 +5,2 @@', curr[1].hunk.header)
      eq(5, prev[1].hunk.top)
      eq(5, curr[1].hunk.top)
      eq(6, prev[1].hunk.bot)
      eq(6, curr[1].hunk.bot)
      eq('python', prev[1].filetype)
      eq('python', curr[1].filetype)
      eq('app.py', prev[1].filename)
      eq('app.py', curr[1].filename)
    end)

    it('should handle multiple files and hunks', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'file_header',
          filename = 'a.lua',
          filetype = 'lua',
        },
        {
          type = 'hunk',
          hunk = { header = '@@ -1,1 +1,1 @@', diff = { '-x', '+y' }, top = 1, bot = 1 },
          filetype = 'lua',
          filename = 'a.lua',
        },
        {
          type = 'file_header',
          filename = 'b.lua',
          filetype = 'lua',
        },
        {
          type = 'hunk',
          hunk = { header = '@@ -1,1 +1,1 @@', diff = { '-m', '+n' }, top = 1, bot = 1 },
          filetype = 'lua',
          filename = 'b.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(4, #prev)
      eq(4, #curr)
      eq('file_header', prev[1].type)
      eq('hunk', prev[2].type)
      eq('file_header', prev[3].type)
      eq('hunk', prev[4].type)
    end)

    it('should handle empty diff in hunk', function()
      local view = ProjectDiffView()
      local entries = {
        {
          type = 'hunk',
          hunk = { header = '@@ -1,0 +1,0 @@', diff = {} },
          filetype = 'lua',
          filename = 'test.lua',
        },
      }

      local prev, curr = view:_build_split_patch_entries(entries)

      eq(0, #prev[1].hunk.diff)
      eq(0, #curr[1].hunk.diff)
    end)

    it('should handle empty entries', function()
      local view = ProjectDiffView()
      local prev, curr = view:_build_split_patch_entries({})

      eq(0, #prev)
      eq(0, #curr)
    end)
  end)

  describe('_get_active_component', function()
    it('should return current_component for split layout', function()
      local view = ProjectDiffView()
      view.layout_type = ProjectDiffView.LAYOUT_SPLIT
      view.current_component = 'current'
      view.patch_component = 'patch'

      eq('current', view:_get_active_component())
    end)

    it('should return patch_component for unified layout', function()
      local view = ProjectDiffView()
      view.layout_type = ProjectDiffView.LAYOUT_UNIFIED
      view.current_component = 'current'
      view.patch_component = 'patch'

      eq('patch', view:_get_active_component())
    end)

    it('should return patch_component for nil layout', function()
      local view = ProjectDiffView()
      view.layout_type = nil
      view.patch_component = 'patch'

      eq('patch', view:_get_active_component())
    end)
  end)

end)
