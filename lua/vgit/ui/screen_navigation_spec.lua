local eq = assert.are.same

local emitted_events = {}

package.loaded['vgit.core.lazy'] = nil
package.loaded['vgit.ui.screen_navigation'] = nil
package.loaded['vgit.core.event'] = nil

package.loaded['vgit.core.event'] = {
  emit = function(event_name, data)
    emitted_events[#emitted_events + 1] = { event_name = event_name, data = data }
  end,
}

local screen_navigation = require('vgit.ui.screen_navigation')

describe('screen_navigation:', function()
  before_each(function()
    emitted_events = {}
  end)

  describe('show_diff', function()
    it('should emit VGitNavigate with action diff', function()
      local data = { type = 'file', diff = {} }
      screen_navigation.show_diff(data)

      eq(1, #emitted_events)
      eq('VGitNavigate', emitted_events[1].event_name)
      eq('diff', emitted_events[1].data.action)
      eq(data, emitted_events[1].data.data)
    end)

    it('should pass data through unchanged', function()
      local data = {
        type = 'files',
        entries = { { title = 'test' } },
        layout_type = 'unified',
      }
      screen_navigation.show_diff(data)

      eq(data, emitted_events[1].data.data)
    end)
  end)

  describe('show_blame_view', function()
    it('should emit VGitNavigate with action blame', function()
      local data = { filename = 'test.lua', blames = {} }
      screen_navigation.show_blame_view(data)

      eq(1, #emitted_events)
      eq('VGitNavigate', emitted_events[1].event_name)
      eq('blame', emitted_events[1].data.action)
      eq(data, emitted_events[1].data.data)
    end)

    it('should pass data through unchanged', function()
      local data = {
        filename = 'file.lua',
        filetype = 'lua',
        reponame = '/repo',
        blames = { {} },
        lines = { 'line1' },
      }
      screen_navigation.show_blame_view(data)

      eq(data, emitted_events[1].data.data)
    end)
  end)
end)
