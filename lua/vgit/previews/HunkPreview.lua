local dimensions = require('vgit.dimensions')
local fs = require('vgit.fs')
local utils = require('vgit.utils')
local CodeComponent = require('vgit.components.CodeComponent')
local Preview = require('vgit.Preview')
local render_store = require('vgit.stores.render_store')

local config = render_store.get('layout').hunk_preview

local HunkPreview = Preview:extend()

function HunkPreview:new(opts)
  local this = Preview:new({
    preview = CodeComponent:new({
      border = utils.retrieve(config.border),
      header = {
        enabled = false,
      },
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.background_hl) or ''
        ),
        ['cursorbind'] = true,
        ['scrollbind'] = true,
        ['cursorline'] = true,
      },
      window_props = {
        style = 'minimal',
        relative = 'cursor',
        height = utils.retrieve(config.height),
        width = dimensions.global_width(),
      },
      filetype = opts.filetype,
    }),
  }, {
    temporary = true,
    layout_type = 'horizontal',
    selected = 1,
  })
  return setmetatable(this, HunkPreview)
end

function HunkPreview:set_cursor(row, col)
  self:get_components().preview:set_cursor(row, col)
  return self
end

function HunkPreview:reposition_cursor(lnum)
  local new_lines_added = 0
  local hunks = self.data.diff_change.hunks
  for i = 1, #hunks do
    local hunk = hunks[i]
    local type = hunk.type
    local diff = hunk.diff
    local current_new_lines_added = 0
    if type == 'remove' then
      for _ = 1, #diff do
        current_new_lines_added = current_new_lines_added + 1
      end
    elseif type == 'change' then
      for j = 1, #diff do
        local line = diff[j]
        local line_type = line:sub(1, 1)
        if line_type == '-' then
          current_new_lines_added = current_new_lines_added + 1
        end
      end
    end
    new_lines_added = new_lines_added + current_new_lines_added
    local start = hunk.start + new_lines_added
    local finish = hunk.finish + new_lines_added
    local padded_lnum = lnum + new_lines_added
    if padded_lnum >= start and padded_lnum <= finish then
      if type == 'remove' then
        self:set_cursor(start - current_new_lines_added + 1, 0)
      else
        self:set_cursor(start - current_new_lines_added, 0)
      end
      vim.cmd('norm! zt')
      break
    end
  end
end

function HunkPreview:render()
  if not self:is_mounted() then
    return
  end
  local err, data = self.err, self.data
  self:clear()
  if err then
    self:set_error(true)
    return self
  end
  if data then
    local diff_change = data.diff_change
    local filename = fs.short_filename(data.filename)
    local filetype = data.filetype
    local components = self:get_components()
    local component = components.preview
    component:set_lines(diff_change.lines)
    component:set_title('Hunk:', filename, filetype)
    self:highlight_diff_change(diff_change)
    self:reposition_cursor(self.selected)
  end
  return self
end

return HunkPreview
