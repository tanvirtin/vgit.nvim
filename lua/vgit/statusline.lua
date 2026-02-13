local statusline_state = require('vgit.core.statusline_state')

local statusline = {}

statusline.get_hunk = statusline_state.get_hunk
statusline.get_diff_stats = statusline_state.get_diff_stats
statusline.get_branch = statusline_state.get_branch

return statusline
