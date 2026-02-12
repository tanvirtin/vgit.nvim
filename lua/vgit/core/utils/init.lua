-- Standard utility functions used throughout the app.

local lazy = require('vgit.core.lazy')

local utils = {
  str = lazy('vgit.core.utils.str'),
  list = lazy('vgit.core.utils.list'),
  date = lazy('vgit.core.utils.date'),
  math = lazy('vgit.core.utils.math'),
  object = lazy('vgit.core.utils.object'),
}

return utils
