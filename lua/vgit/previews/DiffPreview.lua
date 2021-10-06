local CodeComponent = require('vgit.components.CodeComponent')
local utils = require('vgit.utils')
local fs = require('vgit.fs')
local Preview = require('vgit.Preview')
local render_store = require('vgit.stores.render_store')

local config = render_store.get('layout').diff_preview

local DiffPreview = Preview:extend()

local function create_horizontal_widget(opts)
  return Preview:new({
    preview = CodeComponent:new({
      filetype = opts.filetype,
      border = utils.retrieve(config.horizontal.border),
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          config.horizontal.background_hl or ''
        ),
        ['cursorline'] = true,
        ['cursorbind'] = true,
        ['scrollbind'] = true,
      },
      window_props = {
        style = 'minimal',
        relative = 'editor',
        width = utils.retrieve(config.horizontal.width),
        height = utils.retrieve(config.horizontal.height),
        row = utils.retrieve(config.horizontal.row),
        col = utils.retrieve(config.horizontal.col),
      },
      virtual_line_nr = {
        enabled = true,
      },
    }),
  }, opts)
end

local function create_vertical_widget(opts)
  return Preview:new({
    previous = CodeComponent:new({
      filetype = opts.filetype,
      border = utils.retrieve(config.vertical.previous.border),
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          config.vertical.previous.background_hl or ''
        ),
        ['cursorbind'] = true,
        ['scrollbind'] = true,
        ['cursorline'] = true,
      },
      window_props = {
        style = 'minimal',
        relative = 'editor',
        width = utils.retrieve(config.vertical.previous.width),
        height = utils.retrieve(config.vertical.previous.height),
        row = utils.retrieve(config.vertical.previous.row),
        col = utils.retrieve(config.vertical.previous.col),
      },
      virtual_line_nr = {
        enabled = true,
      },
    }),
    current = CodeComponent:new({
      filetype = opts.filetype,
      border = utils.retrieve(config.vertical.current.border),
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          config.vertical.previous.background_hl or ''
        ),
        ['cursorbind'] = true,
        ['scrollbind'] = true,
        ['cursorline'] = true,
      },
      window_props = {
        style = 'minimal',
        relative = 'editor',
        width = utils.retrieve(config.vertical.current.width),
        height = utils.retrieve(config.vertical.current.height),
        row = utils.retrieve(config.vertical.current.row),
        col = utils.retrieve(config.vertical.current.col),
      },
      virtual_line_nr = {
        enabled = true,
      },
    }),
  }, opts)
end

function DiffPreview:new(opts)
  local this = create_vertical_widget(opts)
  if opts.layout_type == 'horizontal' then
    this = create_horizontal_widget(opts)
  end
  return setmetatable(this, DiffPreview)
end

function DiffPreview:set_cursor(row, col)
  if self.layout_type == 'vertical' then
    self:get_components().previous:set_cursor(row, col)
    self:get_components().current:set_cursor(row, col)
  else
    self:get_components().preview:set_cursor(row, col)
  end
  return self
end

function DiffPreview:reposition_cursor(lnum)
  local new_lines_added = 0
  local diff_change = self.data.diff_change
  for i = 1, #diff_change.hunks do
    local hunk = diff_change.hunks[i]
    local type = hunk.type
    local diff = hunk.diff
    local current_new_lines_added = 0
    if type == 'remove' then
      for _ = 1, #diff do
        current_new_lines_added = current_new_lines_added + 1
      end
    elseif type == 'change' then
      local removed_lines, added_lines = hunk:parse_diff()
      if self.layout_type == 'vertical' then
        if #removed_lines ~= #added_lines and #removed_lines > #added_lines then
          current_new_lines_added = current_new_lines_added
            + (#removed_lines - #added_lines)
        end
      else
        current_new_lines_added = current_new_lines_added + #removed_lines
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
      vim.cmd('norm! zz')
      return
    end
  end
  local hunk = diff_change.hunks[1]
  if hunk then
    local start = hunk.start
    if hunk.type == 'remove' then
      start = start + 1
    end
    self:set_cursor(start, 0)
    vim.cmd('norm! zz')
  end
end

function DiffPreview:render()
  if not self:is_mounted() then
    return
  end
  local err, data = self.err, self.data
  self:clear()
  if err then
    self:set_error(true)
    return self
  end
  local diff_change = data.diff_change
  local filename = fs.short_filename(data.filename)
  local filetype = data.filetype
  if diff_change then
    if self.layout_type == 'horizontal' then
      local components = self:get_components()
      components.preview
        :set_lines(diff_change.lines)
        :set_title('Diff Preview:', filename, filetype)
    else
      local components = self:get_components()
      components.previous
        :set_lines(diff_change.previous_lines)
        :set_title('Diff Preview:', filename, filetype)
      components.current:set_lines(diff_change.current_lines)
    end
    self:make_virtual_line_nr(diff_change)
    self:highlight_diff_change(diff_change)
    self:reposition_cursor(self.selected)
  end
  return self
end

return DiffPreview
