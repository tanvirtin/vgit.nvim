local render_store = require('vgit.stores.render_store')
local utils = require('vgit.utils')
local fs = require('vgit.fs')
local TableComponent = require('vgit.components.TableComponent')
local CodeComponent = require('vgit.components.CodeComponent')
local Preview = require('vgit.Preview')

local config = render_store.get('layout').history_preview

local function create_horizontal_widget(opts)
  return Preview:new({
    preview = CodeComponent:new({
      filetype = opts.filetype,
      border = utils.retrieve(config.horizontal.preview.border),
      buf_options = {
        ['modifiable'] = false,
        ['buflisted'] = false,
        ['bufhidden'] = 'wipe',
      },
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.horizontal.preview.background_hl) or ''
        ),
        ['cursorline'] = true,
        ['wrap'] = false,
        ['cursorbind'] = true,
        ['scrollbind'] = true,
      },
      window_props = {
        style = 'minimal',
        relative = 'editor',
        height = utils.retrieve(config.horizontal.preview.height),
        width = utils.retrieve(config.horizontal.preview.width),
        row = utils.retrieve(config.horizontal.preview.row),
        col = utils.retrieve(config.horizontal.preview.col),
      },
      virtual_line_nr = {
        enabled = true,
      },
    }),
    table = TableComponent:new({
      header = { 'Revision', 'Author Name', 'Commit Hash', 'Summary', 'Time' },
      static = true,
      title = 'History',
      border = utils.retrieve(config.horizontal.table.border),
      buf_options = {
        ['modifiable'] = false,
        ['buflisted'] = false,
        ['bufhidden'] = 'wipe',
      },
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.horizontal.table.background_hl) or ''
        ),
        ['cursorline'] = true,
        ['cursorbind'] = false,
        ['scrollbind'] = false,
        ['wrap'] = false,
      },
      window_props = {
        style = 'minimal',
        relative = 'editor',
        height = utils.retrieve(config.horizontal.table.height),
        width = utils.retrieve(config.horizontal.table.width),
        row = utils.retrieve(config.horizontal.table.row),
        col = utils.retrieve(config.horizontal.table.col),
      },
    }),
  }, opts)
end

local function create_vertical_widget(opts)
  return Preview:new({
    previous = CodeComponent:new({
      filetype = opts.filetype,
      border = utils.retrieve(config.vertical.previous.border),
      buf_options = {
        ['modifiable'] = false,
        ['buflisted'] = false,
        ['bufhidden'] = 'wipe',
      },
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.vertical.previous.background_hl) or ''
        ),
        ['cursorline'] = true,
        ['wrap'] = false,
        ['cursorbind'] = true,
        ['scrollbind'] = true,
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
      buf_options = {
        ['modifiable'] = false,
        ['buflisted'] = false,
        ['bufhidden'] = 'wipe',
      },
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.vertical.current.background_hl) or ''
        ),
        ['cursorline'] = true,
        ['wrap'] = false,
        ['cursorbind'] = true,
        ['scrollbind'] = true,
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
    table = TableComponent:new({
      header = { 'Revision', 'Author Name', 'Commit Hash', 'Summary', 'Time' },
      static = true,
      border = utils.retrieve(config.vertical.table.border),
      buf_options = {
        ['modifiable'] = false,
        ['buflisted'] = false,
        ['bufhidden'] = 'wipe',
      },
      win_options = {
        ['winhl'] = string.format(
          'Normal:%s',
          utils.retrieve(config.vertical.table.background_hl) or ''
        ),
        ['cursorline'] = true,
        ['cursorbind'] = false,
        ['scrollbind'] = false,
        ['wrap'] = false,
      },
      window_props = {
        style = 'minimal',
        relative = 'editor',
        width = utils.retrieve(config.vertical.table.width),
        height = utils.retrieve(config.vertical.table.height),
        row = utils.retrieve(config.vertical.table.row),
        col = utils.retrieve(config.vertical.table.col),
      },
    }),
  }, opts)
end

local HistoryPreview = Preview:extend()

function HistoryPreview:new(opts)
  local this = create_vertical_widget(opts)
  if opts.layout_type == 'horizontal' then
    this = create_horizontal_widget(opts)
  end
  return setmetatable(this, HistoryPreview)
end

function HistoryPreview:mount()
  if self.state.mounted then
    return self
  end
  Preview.mount(self)
  local table = self:get_components().table
  table:add_keymap(
    '<enter>',
    string.format('_rerender_history(%s)', self:get_parent_buf())
  )
  table:add_keymap(
    '<2-LeftMouse>',
    string.format('_rerender_history(%s)', self:get_parent_buf())
  )
  table:focus()
  return self
end

function HistoryPreview:make_table()
  local logs = self.data.logs
  local components = self:get_components()
  local table = components.table
  local rows = {}
  for i = 1, #logs do
    local log = logs[i]
    rows[#rows + 1] = {
      log.revision,
      log.author_name or '',
      log.commit_hash or '',
      log.summary or '',
      (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp))) or '',
    }
  end
  table:set_lines(rows)
  local column_ranges = table:get_column_ranges()
  local column_hls = { '', '', 'Keyword', '', '' }
  for i = 1, #rows do
    for j = 1, #column_ranges do
      local r = column_ranges[j]
      vim.api.nvim_buf_add_highlight(
        table:get_buf(),
        -1,
        column_hls[j],
        i - 1,
        r[1],
        r[2]
      )
    end
  end
end

function HistoryPreview:show_indicator()
  local components = self:get_components()
  local table = components.table
  table:transpose_text({
    render_store.get('preview').symbols.indicator,
    render_store.get('preview').indicator_hl,
  }, self.selected, 0)
end

function HistoryPreview:render()
  if not self:is_mounted() then
    return
  end
  local err, data = self.err, self.data
  local components = self:get_components()
  local table = components.table
  self:clear()
  if err then
    self:set_error(true)
    self:show_indicator()
    return self
  elseif data then
    local diff_change = data.diff_change
    local filename = fs.short_filename(data.filename)
    local filetype = data.filetype
    if self.layout_type == 'horizontal' then
      components.preview
        :set_cursor(1, 0)
        :set_lines(diff_change.lines)
        :set_title('History:', filename, filetype)
    else
      components.previous
        :set_cursor(1, 0)
        :set_lines(diff_change.previous_lines)
        :set_title('History:', filename, filetype)
      components.current:set_cursor(1, 0):set_lines(diff_change.current_lines)
    end
    if not table:has_lines() then
      self:make_table()
    end
    self:show_indicator()
    self:make_virtual_line_nr(diff_change)
    self:highlight_diff_change(diff_change)
  else
    table:set_centered_text('There are no commits')
    table:remove_keymap('<enter>')
    table:remove_keymap('<2-LeftMouse>')
  end
  table:focus()
  return self
end

return HistoryPreview
