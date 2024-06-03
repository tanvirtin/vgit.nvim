local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local AppBarView = require('vgit.ui.views.AppBarView')
local Store = require('vgit.features.screens.DiffScreen.Store')
local diff_preview_setting = require('vgit.settings.diff_preview')
local Mutation = require('vgit.features.screens.DiffScreen.Mutation')

local DiffScreen = Object:extend()

function DiffScreen:create_diff_view(scene, store, opts)
  local layout_type = opts.layout_type or 'unified'
  if opts.is_hunk then
    return DiffView(scene, store, { relative = 'cursor', height = '35vh' }, {
      elements = {
        header = true,
        footer = true,
      },
    }, layout_type)
  end

  return DiffView(scene, store, { row = 1 }, {
    elements = {
      header = true,
      footer = false,
    },
  }, layout_type)
end

function DiffScreen:create_app_bar_view(scene, store, opts)
  if opts.is_hunk then return nil end

  return AppBarView(scene, store)
end

function DiffScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()
  local mutation = Mutation()
  local layout_type = opts.layout_type or 'unified'

  return {
    name = 'Diff Screen',
    scene = scene,
    store = store,
    mutation = mutation,
    layout_type = layout_type,
    is_staged = nil,
    diff_view = DiffScreen:create_diff_view(scene, store, opts),
    app_bar_view = DiffScreen:create_app_bar_view(scene, store, opts),
  }
end

function DiffScreen:hunk_up()
  pcall(self.diff_view.prev, self.diff_view, 'center')

  return self
end

function DiffScreen:hunk_down()
  pcall(self.diff_view.next, self.diff_view, 'center')

  return self
end

function DiffScreen:render_help_bar()
  local text = ''
  local keymaps = diff_preview_setting:get('keymaps')
  local keys = {
    'buffer_stage',
    'buffer_unstage',
    'buffer_hunk_stage',
    'buffer_hunk_unstage',
    'reset',
    'toggle_view',
  }
  local translations = {
    'Stage',
    'Unstage',
    'Stage hunk',
    'Unstage hunk',
    'Reset',
    'Toggle view',
  }

  for i = 1, #keys do
    text = i == 1 and string.format('%s (%s)', translations[i], keymaps[keys[i]])
      or string.format('%s | %s (%s)', text, translations[i], keymaps[keys[i]])
  end

  self.app_bar_view:set_lines({ text })
  self.app_bar_view:add_pattern_highlight('%((%a+)%)', 'Keyword')
  self.app_bar_view:add_pattern_highlight('|', 'Number')

  return self
end

function DiffScreen:show(opts)
  opts = opts or {}

  self.is_staged = opts.is_staged or false
  local buffer = Buffer(0)
  local window = Window(0)
  local lnum = window:get_lnum()
  local layout_type = self.layout_type
  local title = self.is_staged and 'Staged Diff' or 'Diff'

  loop.free_textlock()
  local err = self.store:fetch(layout_type, buffer:get_name(), opts)

  if err then
    loop.free_textlock()
    console.debug.error(err).error(err)
    return false
  end

  loop.free_textlock()

  if self.app_bar_view then
    self.app_bar_view:define()
    self.app_bar_view:show()
  end

  self.diff_view:set_title(title)
  self.diff_view:define()
  self.diff_view:show('center', lnum)
  self.diff_view:set_keymap({
    {
      mode = 'n',
      key = diff_preview_setting:get('keymaps').reset,
      handler = loop.debounce_coroutine(function()
        loop.free_textlock()
        local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

        if decision ~= 'yes' and decision ~= 'y' then return end

        loop.free_textlock()
        local _, filename = self.store:get_filename()
        loop.free_textlock()

        if not filename then return end

        loop.free_textlock()
        self.mutation:reset_file(filename)
        loop.free_textlock()

        loop.free_textlock()
        local refetch_err = self.store:fetch(layout_type, buffer:get_name(), opts)
        loop.free_textlock()

        if refetch_err then
          console.debug.error(refetch_err).error(refetch_err)
          return
        end

        loop.free_textlock()
        self.diff_view:render()
      end, 100),
    },
    {
      mode = 'n',
      key = diff_preview_setting:get('keymaps').buffer_stage,
      handler = loop.debounce_coroutine(function()
        loop.free_textlock()
        local _, filename = self.store:get_filename()
        loop.free_textlock()

        if not filename then return end

        loop.free_textlock()
        self.mutation:stage_file(filename)
        loop.free_textlock()

        loop.free_textlock()
        local refetch_err = self.store:fetch(layout_type, buffer:get_name(), opts)
        loop.free_textlock()

        if refetch_err then
          console.debug.error(refetch_err).error(refetch_err)
          return
        end

        loop.free_textlock()
        self.diff_view:render()
      end, 100),
    },
    {
      mode = 'n',
      key = diff_preview_setting:get('keymaps').buffer_unstage,
      handler = loop.debounce_coroutine(function()
        loop.free_textlock()
        local _, filename = self.store:get_filename()
        loop.free_textlock()

        if not filename then return end

        loop.free_textlock()
        self.mutation:unstage_file(filename)
        loop.free_textlock()

        loop.free_textlock()
        local refetch_err = self.store:fetch(layout_type, buffer:get_name(), opts)
        loop.free_textlock()

        if refetch_err then
          console.debug.error(refetch_err).error(refetch_err)
          return
        end

        loop.free_textlock()
        self.diff_view:render()
      end, 100),
    },
    {
      mode = 'n',
      key = diff_preview_setting:get('keymaps').buffer_hunk_stage,
      handler = loop.debounce_coroutine(function()
        if self.is_staged then return end

        loop.free_textlock()
        local _, filename = self.store:get_filename()
        loop.free_textlock()

        if not filename then return end

        loop.free_textlock()
        local hunk, index = self.diff_view:get_current_hunk_under_cursor()
        loop.free_textlock()

        if not hunk then return end

        self.mutation:stage_hunk(filename, hunk)

        loop.free_textlock()
        local refetch_err = self.store:fetch(layout_type, buffer:get_name(), opts)

        if refetch_err then
          console.debug.error(refetch_err).error(refetch_err)
          return
        end

        self.diff_view:render():navigate_to_mark(index, 'center')
      end, 100),
    },
    {
      mode = 'n',
      key = diff_preview_setting:get('keymaps').buffer_hunk_unstage,
      handler = loop.debounce_coroutine(function()
        if not self.is_staged then return end

        loop.free_textlock()
        local _, filename = self.store:get_filename()
        loop.free_textlock()

        if not filename then return end

        loop.free_textlock()
        local hunk, index = self.diff_view:get_current_hunk_under_cursor()
        loop.free_textlock()

        if not hunk then return end

        loop.free_textlock()
        self.mutation:unstage_hunk(filename, hunk)
        loop.free_textlock()

        loop.free_textlock()
        local refetch_err = self.store:fetch(layout_type, buffer:get_name(), opts)
        loop.free_textlock()

        if refetch_err then
          console.debug.error(refetch_err).error(refetch_err)
          return
        end

        loop.free_textlock()
        self.diff_view:render():navigate_to_mark(index, 'center')
      end, 100),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.debounce_coroutine(function()
        loop.free_textlock()
        local mark = self.diff_view:get_current_mark_under_cursor()
        loop.free_textlock()

        if not mark then return end

        loop.free_textlock()
        local _, filename = self.store:get_filename()
        loop.free_textlock()

        if not filename then return end

        self:destroy()
        loop.free_textlock()

        fs.open(filename)

        loop.free_textlock()
        Window(0):set_lnum(mark.top_relative):position_cursor('center')
      end, 100),
    },
    {
      mode = 'n',
      key = diff_preview_setting:get('keymaps').toggle_view,
      handler = loop.debounce_coroutine(function()
        local is_staged = self.is_staged

        if is_staged then
          self.diff_view:set_title('Diff')

          self.is_staged = false
          opts.is_staged = self.is_staged

          loop.free_textlock()
          local refetch_err = self.store:fetch(layout_type, buffer:get_name(), opts)
          loop.free_textlock()

          if refetch_err then
            console.debug.error(refetch_err).error(refetch_err)
            return
          end

          loop.free_textlock()
          self.diff_view:render():navigate_to_mark(1, 'center')
        elseif not is_staged then
          self.diff_view:set_title('Staged Diff')

          self.is_staged = true
          opts.is_staged = self.is_staged

          loop.free_textlock()
          local refetch_err = self.store:fetch(layout_type, buffer:get_name(), opts)
          loop.free_textlock()

          if refetch_err then
            console.debug.error(refetch_err).error(refetch_err)
            return
          end

          loop.free_textlock()
          self.diff_view:render():navigate_to_mark(1, 'center')
        end
      end, 100),
    },
  })

  if self.app_bar_view then self:render_help_bar() end

  return true
end

function DiffScreen:destroy()
  self.scene:destroy()

  return self
end

return DiffScreen
