local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local KeyHelpBarView = require('vgit.ui.views.KeyHelpBarView')
local Model = require('vgit.features.screens.DiffScreen.Model')
local diff_preview_setting = require('vgit.settings.diff_preview')

local DiffScreen = Object:extend()

function DiffScreen:create_diff_view(scene, model)
  local props = {
    layout_type = function()
      return model:get_layout_type()
    end,
    filename = function()
      return model:get_filename()
    end,
    filetype = function()
      return model:get_filetype()
    end,
    diff = function()
      return model:get_diff()
    end,
  }

  if model:is_hunk() then
    return DiffView(scene, props, { relative = 'cursor', height = '35vh' }, {
      elements = {
        header = true,
        footer = true,
      },
    })
  end
  return DiffView(scene, props, { row = 1 }, {
    elements = {
      header = true,
      footer = false,
    },
  })
end

function DiffScreen:create_app_bar_view(scene, model)
  if model:is_hunk() then return nil end
  return KeyHelpBarView(scene, {
    keymaps = function()
      local keymaps = diff_preview_setting:get('keymaps')
      if model:is_staged() then
        return {
          { 'Unstage', keymaps['buffer_unstage'] },
          { 'Unstage hunk', keymaps['buffer_hunk_unstage'] },
          { 'Switch to Staged View', keymaps['toggle_view'] },
        }
      end
      return {
        { 'Stage', keymaps['buffer_stage'] },
        { 'Stage hunk', keymaps['buffer_hunk_stage'] },
        { 'Reset', keymaps['reset'] },
        { 'Switch to Unstage View', keymaps['toggle_view'] },
      }
    end,
  })
end

function DiffScreen:constructor(opts)
  local scene = Scene()
  local model = Model(opts)

  return {
    name = 'Diff Screen',
    scene = scene,
    model = model,
    diff_view = DiffScreen:create_diff_view(scene, model),
    app_bar_view = DiffScreen:create_app_bar_view(scene, model),
  }
end

function DiffScreen:hunk_up()
  self.diff_view.prev(self.diff_view, 'center')
end

function DiffScreen:hunk_down()
  self.diff_view.next(self.diff_view, 'center')
end

function DiffScreen:toggle_view(buffer)
  if self.model:is_hunk() then return end

  local is_staged = self.model:is_staged()
  self.model:toggle_staged()
  loop.free_textlock()

  if is_staged then
    local _, refetch_err = self.model:fetch(buffer:get_name())
    loop.free_textlock()

    if refetch_err then
      console.debug.error(refetch_err).error(refetch_err)
      return
    end

    self.diff_view:render()
    self.diff_view:move_to_hunk(1, 'center')
    if self.app_bar_view then self.app_bar_view:render() end

    return
  end

  local _, refetch_err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if refetch_err then
    console.debug.error(refetch_err).error(refetch_err)
    return
  end

  self.diff_view:render()
  self.diff_view:move_to_hunk(1, 'center')
  if self.app_bar_view then self.app_bar_view:render() end
end

function DiffScreen:reset(buffer)
  if self.model:is_hunk() then return end
  if self.model:is_staged() then return end

  loop.free_textlock()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  loop.free_textlock()
  local filename = self.model:get_filename()
  if not filename then return end

  loop.free_textlock()
  self.model:reset_file(filename)

  loop.free_textlock()
  local _, refetch_err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if refetch_err then
    console.debug.error(refetch_err).error(refetch_err)
    return
  end

  self.diff_view:render()
end

function DiffScreen:enter_view()
  if self.model:is_hunk() then return end

  loop.free_textlock()
  local mark = self.diff_view:get_current_mark_under_cursor()
  if not mark then return end

  loop.free_textlock()
  local filename = self.model:get_filename()
  if not filename then return end

  self:destroy()
  loop.free_textlock()

  fs.open(filename)

  loop.free_textlock()
  Window(0):set_lnum(mark.top_relative):position_cursor('center')
end

function DiffScreen:stage_hunk(buffer)
  if self.model:is_hunk() then return end
  if self.model:is_staged() then return end

  loop.free_textlock()
  local filename = self.model:get_filename()
  if not filename then return end

  loop.free_textlock()
  local hunk, index = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  self.model:stage_hunk(filename, hunk)

  loop.free_textlock()
  local _, refetch_err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if refetch_err then
    console.debug.error(refetch_err).error(refetch_err)
    return
  end

  self.diff_view:render()
  self.diff_view:move_to_hunk(index, 'center')
end

function DiffScreen:unstage_hunk(buffer)
  if self.model:is_hunk() then return end
  if not self.model:is_staged() then return end

  loop.free_textlock()
  local filename = self.model:get_filename()
  if not filename then return end

  loop.free_textlock()
  local hunk, index = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  loop.free_textlock()
  self.model:unstage_hunk(filename, hunk)

  loop.free_textlock()
  local _, refetch_err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if refetch_err then
    console.debug.error(refetch_err).error(refetch_err)
    return
  end

  self.diff_view:render()
  self.diff_view:move_to_hunk(index, 'center')
end

function DiffScreen:stage(buffer)
  if self.model:is_hunk() then return end
  if self.model:is_staged() then return end

  loop.free_textlock()
  local filename = self.model:get_filename()
  if not filename then return end

  loop.free_textlock()
  self.model:stage_file(filename)

  loop.free_textlock()
  local _, refetch_err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if refetch_err then
    console.debug.error(refetch_err).error(refetch_err)
    return
  end
end

function DiffScreen:unstage(buffer)
  if self.model:is_hunk() then return end
  if not self.model:is_staged() then return end

  loop.free_textlock()
  local filename = self.model:get_filename()
  if not filename then return end

  loop.free_textlock()
  self.model:unstage_file(filename)

  loop.free_textlock()
  local _, refetch_err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if refetch_err then
    console.debug.error(refetch_err).error(refetch_err)
    return
  end
end

function DiffScreen:setup_keymaps(buffer)
  local keymaps = diff_preview_setting:get('keymaps')

  self.diff_view:set_keymap({
    {
      mode = 'n',
      mapping = keymaps.reset,
      handler = loop.debounce_coroutine(function()
        self:reset(buffer)
      end, 50),
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_stage,
      handler = loop.debounce_coroutine(function()
        self:stage(buffer)
        self:toggle_view(buffer)
      end, 50),
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_unstage,
      handler = loop.debounce_coroutine(function()
        self:unstage(buffer)
        self:toggle_view(buffer)
      end, 50),
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_hunk_stage,
      handler = loop.debounce_coroutine(function()
        self:stage_hunk(buffer)
      end, 50),
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_hunk_unstage,
      handler = loop.debounce_coroutine(function()
        self:unstage_hunk(buffer)
      end, 50),
    },
    {
      mode = 'n',
      mapping = {
        key = '<enter>',
        desc = 'Open buffer',
      },
      handler = loop.debounce_coroutine(function()
        self:enter_view()
      end, 50),
    },
    {
      mode = 'n',
      mapping = keymaps.toggle_view,
      handler = loop.debounce_coroutine(function()
        self:toggle_view(buffer)
      end, 50),
    },
  })
end

function DiffScreen:create(opts)
  opts = opts or {}

  local buffer = Buffer(0)
  local window = Window(0)
  local lnum = window:get_lnum()

  loop.free_textlock()
  local _, err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  if self.app_bar_view then
    self.app_bar_view:define()
    self.app_bar_view:mount()
  end

  self.diff_view:define()
  self.diff_view:mount()
  self.diff_view:render()

  self:setup_keymaps(buffer)

  local mark_index = self.diff_view:get_relative_mark_index(lnum)
  self.diff_view:move_to_hunk(mark_index, 'center')

  if self.app_bar_view then self.app_bar_view:render() end

  return true
end

function DiffScreen:destroy()
  self.scene:destroy()
end

return DiffScreen
