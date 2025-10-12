local Diff = require('vgit.core.diff.Diff')
local Object = require('vgit.core.Object')
local assertion = require('vgit.core.assertion')

local DiffLayoutGenerator = Object:extend()

function DiffLayoutGenerator:assert_layout_type(layout_type, valid_layout_types)
  for _, valid_layout_type in ipairs(valid_layout_types) do
    if layout_type == valid_layout_type then return true end
  end

  return false
end

function DiffLayoutGenerator:generate(hunks, lines, opts)
  opts = opts or {}
  local conflicts = opts.conflict
  local is_deleted = opts.is_deleted
  local layout_type = opts.layout_type or 'unified'

  assertion.assert(hunks, 'missing hunks').assert(lines, 'missing lines')

  self:assert_layout_type(layout_type, { 'unified', 'split' })

  local diff_obj = Diff({
    hunks = hunks,
    lines = lines,
  })

  local result = diff_obj:generate(hunks, lines, layout_type, {
    conflicts = conflicts,
    is_deleted = is_deleted,
  })

  return result
end

return DiffLayoutGenerator
