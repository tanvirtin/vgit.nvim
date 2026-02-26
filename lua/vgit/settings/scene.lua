local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  diff_preference = 'unified',
  keymaps = { quit = '<esc>' },
})
