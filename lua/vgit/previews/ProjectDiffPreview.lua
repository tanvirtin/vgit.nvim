local TableComponent = require('vgit.components.TableComponent')
local fs = require('vgit.fs')
local utils = require('vgit.utils')
local render_store = require('vgit.stores.render_store')
local CodeComponent = require('vgit.components.CodeComponent')
local icons = require('vgit.icons')
local Preview = require('vgit.Preview')

local config = render_store.get('layout').project_diff_preview

local function create_horizontal_widget(opts)
  return Preview:new({
    preview = CodeComponent:new({
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
        width = utils.retrieve(config.horizontal.preview.width),
        height = utils.retrieve(config.horizontal.preview.height),
        row = utils.retrieve(config.horizontal.preview.row),
        col = utils.retrieve(config.horizontal.preview.col),
      },
      virtual_line_nr = {
        enabled = true,
      },
    }),
    table = TableComponent:new({
      header = { 'Changes' },
      column_spacing = 3,
      max_column_len = 100,
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
        width = utils.retrieve(config.horizontal.table.width),
        height = utils.retrieve(config.horizontal.table.height),
        row = utils.retrieve(config.horizontal.table.row),
        col = utils.retrieve(config.horizontal.table.col),
      },
      static = true,
    }),
  }, opts)
end

local function create_vertical_widget(opts)
  return Preview:new({
    previous = CodeComponent:new({
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
        height = utils.retrieve(config.vertical.previous.height),
        width = utils.retrieve(config.vertical.previous.width),
        row = utils.retrieve(config.vertical.previous.row),
        col = utils.retrieve(config.vertical.previous.col),
      },
      virtual_line_nr = {
        enabled = true,
      },
    }),
    current = CodeComponent:new({
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
        height = utils.retrieve(config.vertical.current.height),
        width = utils.retrieve(config.vertical.current.width),
        row = utils.retrieve(config.vertical.current.row),
        col = utils.retrieve(config.vertical.current.col),
      },
      virtual_line_nr = {
        enabled = true,
      },
    }),
    table = TableComponent:new({
      header = { 'Changes' },
      column_spacing = 3,
      max_column_len = 100,
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
        height = utils.retrieve(config.vertical.table.height),
        width = utils.retrieve(config.vertical.table.width),
        row = utils.retrieve(config.vertical.table.row),
        col = utils.retrieve(config.vertical.table.col),
      },
      static = true,
    }),
  }, opts)
end

local ProjectDiffPreview = Preview:extend()

function ProjectDiffPreview:new(opts)
  local this = create_vertical_widget(opts)
  if opts.layout_type == 'horizontal' then
    this = create_horizontal_widget(opts)
  end
  return setmetatable(this, ProjectDiffPreview)
end

function ProjectDiffPreview:mount()
  if self.state.mounted then
    return self
  end
  Preview.mount(self)
  local components = self:get_components()
  local table = components.table
  table:add_keymap('<enter>', '_rerender_project_diff()')
  table:add_keymap('<2-LeftMouse>', '_rerender_project_diff()')
  table:focus()
  if self.layout_type == 'vertical' then
    components.previous:add_keymap('<enter>', '_select_project_diff()')
    components.current:add_keymap('<enter>', '_select_project_diff()')
  else
    components.preview:add_keymap('<enter>', '_select_project_diff()')
  end
  return self
end

function ProjectDiffPreview:make_table()
  local changed_files = self.data.changed_files
  local components = self:get_components()
  local table = components.table
  local rows = {}
  local spacing = ' '
  local defered = {}
  for i = 1, #changed_files do
    local file = changed_files[i]
    local icon, icon_hl = icons.file_icon(
      file.filename,
      fs.detect_filetype(file.filename)
    )
    local filename = fs.short_filename(file.filename)
    local directory = fs.cwd_filename(file.filename)
    local segments = {
      string.format('%s', spacing),
      string.format(' %s', icon),
      string.format(' %s', filename),
      string.format(' %s', directory),
      string.format(' %s', file.status),
    }
    rows[#rows + 1] = { vim.fn.join(segments, '') }
    defered[#defered + 1] = function()
      if icon_hl then
        vim.api.nvim_buf_add_highlight(
          table:get_buf(),
          -1,
          icon_hl,
          i - 1,
          #segments[1],
          #segments[1] + #segments[2] + 3
        )
      end
    end
    defered[#defered + 1] = function()
      if icon_hl then
        vim.api.nvim_buf_add_highlight(
          table:get_buf(),
          -1,
          'Comment',
          i - 1,
          #segments[1] + #segments[2] + 3 + #segments[3] + 1,
          #segments[1] + #segments[2] + 3 + #segments[3] + #segments[4]
        )
      end
    end
    defered[#defered + 1] = function()
      if icon_hl then
        vim.api.nvim_buf_add_highlight(
          table:get_buf(),
          -1,
          'VGitStatus',
          i - 1,
          #segments[1] + #segments[2] + 3 + #segments[3] + #segments[4] + 1,
          #segments[1]
            + #segments[2]
            + 3
            + #segments[3]
            + #segments[4]
            + #segments[5]
        )
      end
    end
  end
  table:set_lines(rows)
  for i = 1, #defered do
    defered[i]()
  end
end

function ProjectDiffPreview:reposition_cursor()
  local diff_change = self.data.diff_change
  local hunk = diff_change.hunks[1]
  if hunk then
    local start = hunk.start
    if hunk.type == 'remove' then
      start = start + 1
    end
    local components = self:get_components()
    if self.layout_type == 'vertical' then
      components.previous:set_cursor(start, 0):call(function()
        vim.cmd('norm! zz')
      end)
      components.current:set_cursor(start, 0):call(function()
        vim.cmd('norm! zz')
      end)
    else
      components.preview:set_cursor(start, 0):call(function()
        vim.cmd('norm! zz')
      end)
    end
  end
end

function ProjectDiffPreview:show_indicator()
  local components = self:get_components()
  local table = components.table
  table:transpose_text({
    render_store.get('preview').symbols.indicator,
    render_store.get('preview').indicator_hl,
  }, self.selected, 0)
end

function ProjectDiffPreview:render()
  if not self:is_mounted() then
    return
  end
  local components = self:get_components()
  local table = components.table
  local err, data = self.err, self.data
  self:clear()
  if err then
    if err[1] == 'File not found' then
      local file_not_found_msg = 'File has been deleted'
      if self.layout_type == 'horizontal' then
        components.preview
          :set_cursor(1, 0)
          :set_centered_text(file_not_found_msg)
      else
        components.previous
          :set_cursor(1, 0)
          :set_centered_text(file_not_found_msg)
        components.current
          :set_cursor(1, 0)
          :set_centered_text(file_not_found_msg)
      end
      self:show_indicator()
      self:make_table()
      return
    end
    self:set_error(true)
    self:show_indicator()
    return self
  elseif data then
    local diff_change = data.diff_change
    local filetype = data.filetype
    local filename = fs.short_filename(data.filename)
    if self.layout_type == 'horizontal' then
      components.preview
        :set_cursor(1, 0)
        :set_lines(diff_change.lines)
        :set_filetype(filetype)
        :set_title('Project Diff:', filename, filetype)
    else
      components.previous
        :set_cursor(1, 0)
        :set_lines(diff_change.previous_lines)
        :set_filetype(filetype)
        :set_title('Project Diff:', filename, filetype)
      components.current
        :set_cursor(1, 0)
        :set_lines(diff_change.current_lines)
        :set_filetype(filetype)
    end
    if not table:has_lines() then
      self:make_table()
    end
    self:show_indicator()
    self:make_virtual_line_nr(diff_change)
    self:highlight_diff_change(diff_change)
    self:reposition_cursor()
  else
    table:set_centered_text('There are no changes')
    table:remove_keymap('<enter>')
    table:remove_keymap('<2-LeftMouse>')
    if self.layout_type == 'vertical' then
      components.previous:remove_keymap('<enter>')
      components.current:remove_keymap('<enter>')
    else
      components.preview:remove_keymap('<enter>')
    end
  end
  table:focus()
  return self
end

return ProjectDiffPreview
