local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')

local screen_navigation = {}

function screen_navigation.show_diff(data)
  event.emit('VGitNavigate', { action = 'diff', data = data })
end

function screen_navigation.show_blame_view(data)
  event.emit('VGitNavigate', { action = 'blame', data = data })
end

return screen_navigation
