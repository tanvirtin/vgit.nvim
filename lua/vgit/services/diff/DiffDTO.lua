local Object = require('vgit.core.Object')

local DiffDTO = Object:extend()

function DiffDTO:constructor(opts)
  return vim.tbl_extend('force', {
    lines = {},
    current_lines = {},
    previous_lines = {},
    lnum_changes = {},
    hunks = {},
    marks = {},
    stat = {
      added = 0,
      removed = 0,
    },
  }, opts)
end

return DiffDTO
