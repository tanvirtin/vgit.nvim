local fs = require('vgit.core.fs')
local event = require('vgit.core.event')
local utils = require('vgit.core.utils')
local Layout = require('vgit.ui.Layout')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')
local diff_view_setting = require('vgit.settings.diff_view')
local ComponentManager = require('vgit.ui.ComponentManager')
local DiffComponent = require('vgit.ui.components.DiffComponent')
local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')

local FileDiffView = Object:extend()

FileDiffView.DEBOUNCE_MS = 100
FileDiffView.LAYOUT_SPLIT = 'split'
FileDiffView.LAYOUT_UNIFIED = 'unified'

function FileDiffView:constructor()
  return {
    opts = {
      filename = nil,
      is_staged = false,
      cursor_line = false,
      layout_type = self.LAYOUT_UNIFIED,
    },
    data = nil,
    diff_component = nil,
    component_manager = nil,
    debounce_cleanups = {},
  }
end

function FileDiffView:hunk_up()
  self.diff_component:prev('top')
end

function FileDiffView:hunk_down()
  self.diff_component:next('top')
end

function FileDiffView:_handle_git_error(err, operation_name)
  if err then
    console.debug.error(string.format('[FileDiffView] %s failed: %s', operation_name, err))
    return false
  end
  return true
end

function FileDiffView:_refresh_diff_data()
  local repo, err = repository.current()
  if not self:_handle_git_error(err, 'repository.current') then return end

  local scene_setting = require('vgit.settings.scene')
  local current_layout_type = scene_setting:get('diff_preference') or FileDiffView.LAYOUT_UNIFIED

  local diff_spec
  if self.opts.is_staged then
    diff_spec = {
      type = 'range',
      filename = self.opts.filename,
      from = 'HEAD',
      to = 'index',
      layout_type = current_layout_type,
    }
  else
    diff_spec = {
      type = 'range',
      filename = self.opts.filename,
      from = 'index',
      to = 'disk',
      layout_type = current_layout_type,
    }
  end

  event.await()
  local diff = repo:diff(diff_spec)
  if not diff then return end

  return {
    diff = diff,
    filename = self.opts.filename,
    filetype = fs.detect_filetype(self.opts.filename),
    layout_type = current_layout_type,
    is_staged = self.opts.is_staged,
  }
end

function FileDiffView:_process_file_data(data)
  self.opts = utils.object.defaults({
    filename = data.filename,
    is_staged = data.is_staged,
    cursor_line = data.cursor_line,
    layout_type = data.layout_type,
  }, self.opts)

  self.data = data

  local diff_data = {
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
    target_hunk_index = data.target_hunk_index,
  }

  return self:_create_file_view(diff_data)
end

function FileDiffView:create(data)
  if not data then
    console.error('[FileDiffView] No data provided to create()')
    return false
  end

  if type(data) ~= 'table' then
    console.error('[FileDiffView] Expected table, got ' .. type(data))
    return false
  end

  if not data.diff or utils.object.is_empty(data.diff) then
    console.error('[FileDiffView] Invalid file data: missing or empty diff')
    return false
  end
  if not data.filename or data.filename:match('^%s*$') then
    console.error('[FileDiffView] Invalid file data: missing or empty filename')
    return false
  end

  if data.filetype and type(data.filetype) ~= 'string' then
    console.warn('[FileDiffView] Invalid filetype, using default')
    return false
  end

  return self:_process_file_data(data)
end

function FileDiffView:create_diff_component(opts)
  opts = opts or {}
  local layout_type = self.opts.layout_type or self.LAYOUT_UNIFIED

  local props = {
    diff = opts.diff,
    filename = opts.filename,
    filetype = opts.filetype or 'text',
  }

  if layout_type == self.LAYOUT_SPLIT then return SplitDiffComponent(props) end
  return DiffComponent(props)
end

function FileDiffView:_create_file_view(data)
  self.diff_component = self:create_diff_component({
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
  })

  self.component_manager = ComponentManager()
  event.await()
  self.component_manager:render(Layout.screen(self.diff_component))

  local target_hunk = 1

  if data.target_hunk_index then
    target_hunk = data.target_hunk_index
  elseif not self.opts.cursor_line then
    local lnum = Window(0):get_lnum()
    target_hunk = self.diff_component:get_relative_mark_index(lnum)
  end

  self.diff_component:move_to_hunk(target_hunk, 'top')

  self:setup_keymaps()

  return true
end

function FileDiffView:_update_diff_component(hunk_index)
  if not self.diff_component or not self.diff_component:is_valid() then return false end

  event.await()
  local data = self:_refresh_diff_data()
  if not data then return false end

  if not self.diff_component or not self.diff_component:is_valid() then return false end
  event.await()
  self.diff_component:set_props({
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
  })

  if not self.diff_component or not self.diff_component:is_valid() then return false end
  event.await()
  if hunk_index then self.diff_component:move_to_hunk(hunk_index, 'top') end

  return true
end

function FileDiffView:toggle_view()
  if self.opts.filename then
    self.opts.is_staged = not self.opts.is_staged

    local data = self:_refresh_diff_data()
    if not data then
      self.opts.is_staged = not self.opts.is_staged
      return
    end

    event.await()
    self.diff_component:set_props({
      diff = data.diff,
      filename = data.filename,
      filetype = data.filetype,
    })
    self.diff_component:move_to_hunk(1, 'top')
  end
end

function FileDiffView:reset_current()
  if self.opts.is_staged then return end

  event.await()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  event.await()
  local filename = self.opts.filename
  if not filename then return end

  event.await()
  local repo, err = repository.current()
  if err then return end
  repo:reset(filename)

  event.await()
  local data = self:_refresh_diff_data()
  if not data then return end

  self.diff_component:set_props({
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
  })
end

function FileDiffView:enter_view()
  event.await()
  local mark = self.diff_component:get_current_mark_under_cursor()
  if not mark then return end

  event.await()
  local filename = self.opts.filename
  if not filename then return end

  self:destroy()
  event.await()

  fs.open(filename)

  event.await()
  Window(0):set_lnum(mark.top_relative):position_cursor('center')
end

function FileDiffView:stage_hunk()
  event.await()

  local filename = self.opts.filename
  if not filename then return end
  if self.opts.is_staged then return end

  local hunk, index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  event.await()
  local repo, err = repository.current()
  if err then return end

  event.await()
  repo:stage_hunk(filename, hunk)

  self:_update_diff_component(index)
end

function FileDiffView:unstage_hunk()
  event.await()

  local filename = self.opts.filename
  if not filename then return end
  if not self.opts.is_staged then return end

  local hunk, index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  event.await()
  local repo, err = repository.current()
  if err then return end

  event.await()
  repo:unstage_hunk(filename, hunk)

  self:_update_diff_component(index)
end

function FileDiffView:stage_current()
  if self.opts.is_staged then return end

  event.await()
  local filename = self.opts.filename
  if not filename then return end

  event.await()
  local repo, err = repository.current()
  if err then return end

  event.await()
  repo:stage_file(filename)

  self:_update_diff_component()
end

function FileDiffView:unstage_current()
  if not self.opts.is_staged then return end

  event.await()
  local filename = self.opts.filename
  if not filename then return end

  event.await()
  local repo, err = repository.current()
  if err then return end

  event.await()
  repo:unstage_file(filename)

  self:_update_diff_component()
end

function FileDiffView:get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
  return nil
end

function FileDiffView:setup_keymaps()
  local scene_setting = require('vgit.settings.scene')
  local scene_keymaps = scene_setting:get('keymaps')
  local diff_keymaps = diff_view_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      self.diff_component:set_keymap({
        mode = 'n',
        key = quit_key,
      }, function()
        self.component_manager:destroy()
      end)
    end
  end

  local hunk_up_key = self:get_key(diff_keymaps.hunk_up)
  if hunk_up_key then
    local hunk_up_fn, hunk_up_cleanup = event.debounce_async(function()
      self:hunk_up()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, hunk_up_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = hunk_up_key,
      },
      hunk_up_fn
    )
  end

  local hunk_down_key = self:get_key(diff_keymaps.hunk_down)
  if hunk_down_key then
    local hunk_down_fn, hunk_down_cleanup = event.debounce_async(function()
      self:hunk_down()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, hunk_down_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = hunk_down_key,
      },
      hunk_down_fn
    )
  end

  local stage_key = self:get_key(diff_keymaps.stage)
  if stage_key then
    local stage_fn, stage_cleanup = event.debounce_async(function()
      self:stage_current()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, stage_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = stage_key,
      },
      stage_fn
    )
  end

  local unstage_key = self:get_key(diff_keymaps.unstage)
  if unstage_key then
    local unstage_fn, unstage_cleanup = event.debounce_async(function()
      self:unstage_current()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, unstage_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = unstage_key,
      },
      unstage_fn
    )
  end

  local reset_key = self:get_key(diff_keymaps.reset)
  if reset_key then
    local reset_fn, reset_cleanup = event.debounce_async(function()
      self:reset_current()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, reset_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = reset_key,
      },
      reset_fn
    )
  end

  local stage_hunk_key = self:get_key(diff_keymaps.stage_hunk)
  if stage_hunk_key then
    local stage_hunk_fn, stage_hunk_cleanup = event.debounce_async(function()
      self:stage_hunk()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, stage_hunk_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = stage_hunk_key,
      },
      stage_hunk_fn
    )
  end

  local unstage_hunk_key = self:get_key(diff_keymaps.unstage_hunk)
  if unstage_hunk_key then
    local unstage_hunk_fn, unstage_hunk_cleanup = event.debounce_async(function()
      self:unstage_hunk()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, unstage_hunk_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = unstage_hunk_key,
      },
      unstage_hunk_fn
    )
  end

  local toggle_view_key = self:get_key(diff_keymaps.toggle_view)
  if toggle_view_key then
    local toggle_view_fn, toggle_view_cleanup = event.debounce_async(function()
      self:toggle_view()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, toggle_view_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = toggle_view_key,
      },
      toggle_view_fn
    )
  end

  local enter_fn, enter_cleanup = event.debounce_async(function()
    self:enter_view()
  end, self.DEBOUNCE_MS)
  table.insert(self.debounce_cleanups, enter_cleanup)
  self.diff_component:set_keymap(
    {
      mode = 'n',
      key = '<enter>',
    },
    enter_fn
  )
end

function FileDiffView:emit_cleanup_events()
  self.diff_component:component_will_unmount()
end

function FileDiffView:destroy()
  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}
  self:emit_cleanup_events()
  self.component_manager:destroy()
end

return FileDiffView
