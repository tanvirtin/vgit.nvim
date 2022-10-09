local event_type = {}

-- Buffer events
event_type.BufAdd = 'BufAdd'
event_type.BufRead = 'BufRead'
event_type.BufEnter = 'BufEnter'
event_type.BufWinEnter = 'BufWinEnter'
event_type.BufWinLeave = 'BufWinLeave'

-- Win events
event_type.WinEnter = 'WinEnter'

-- Insert events
event_type.InsertEnter = 'InsertEnter'

-- Cursor events
event_type.CursorHold = 'CursorHold'
event_type.CursorMoved = 'CursorMoved'

-- Colorscheme events
event_type.ColorScheme = 'ColorScheme'

-- Git events
event_type.VGitBufAttached = 'VGitBufAttached'
event_type.VGitBufDetached = 'VGitBufDetached'

return event_type
