local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local Feature = require('vgit.Feature')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local diff_preview = require('vgit.settings.diff_preview')
local Query = require('vgit.features.screens.DiffScreen.Query')
local Mutation = require('vgit.features.screens.DiffScreen.Mutation')

local DiffScreen = Feature:extend()

function DiffScreen:create_code_view(scene, query, opts)
  if opts.is_hunk then
    return CodeView(scene, query, {
      relative = 'cursor',
      height = '35vh',
    }, {
      elements = {
        header = true,
        footer = true,
      },
    })
  end

  return CodeView(scene, query)
end

function DiffScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local query = Query()
  local mutation = Mutation()

  return {
    name = 'Diff Screen',
    scene = scene,
    query = query,
    mutation = mutation,
    layout_type = nil,
    is_staged = nil,
    code_view = DiffScreen:create_code_view(scene, query, opts),
  }
end

function DiffScreen:hunk_up()
  pcall(self.code_view.prev, self.code_view, 'center')

  return self
end

function DiffScreen:hunk_down()
  pcall(self.code_view.next, self.code_view, 'center')

  return self
end

function DiffScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function DiffScreen:show(opts)
  opts = opts or {}

  console.log('Processing diff')

  self.is_staged = opts.is_staged or false
  local query = self.query
  local layout_type = self.layout_type
  local buffer = Buffer(0)

  loop.await_fast_event()
  local err = query:fetch(layout_type, buffer.filename, opts)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.code_view
    :set_title(self.is_staged and 'Staged Diff' or 'Diff')
    :show(layout_type, 'center', { winline = vim.fn.winline() })
    :set_keymap({
      {
        mode = 'n',
        key = diff_preview:get('keymaps').reset,
        vgit_key = string.format('keys.%s', diff_preview:get('keymaps').reset),
        handler = loop.debounced_async(function()
          loop.await_fast_event()
          local decision = console.input(
            'Are you sure you want to discard all unstaged changes? (y/N) '
          ):lower()

          if decision ~= 'yes' and decision ~= 'y' then
            return
          end

          loop.await_fast_event()
          local _, filename = self.query:get_filename()
          loop.await_fast_event()

          if not filename then
            return
          end

          loop.await_fast_event()
          self.mutation:reset_file(filename)
          loop.await_fast_event()

          loop.await_fast_event()
          local refetch_err = query:fetch(layout_type, buffer.filename, opts)
          loop.await_fast_event()

          if refetch_err then
            console.debug.error(refetch_err).error(refetch_err)
            return
          end

          loop.await_fast_event()
          self.code_view:render()
        end, 100),
      },
      {
        mode = 'n',
        key = diff_preview:get('keymaps').buffer_stage,
        vgit_key = string.format(
          'keys.%s',
          diff_preview:get('keymaps').buffer_stage
        ),
        handler = loop.debounced_async(function()
          loop.await_fast_event()
          local _, filename = self.query:get_filename()
          loop.await_fast_event()

          if not filename then
            return
          end

          loop.await_fast_event()
          self.mutation:stage_file(filename)
          loop.await_fast_event()

          loop.await_fast_event()
          local refetch_err = query:fetch(layout_type, buffer.filename, opts)
          loop.await_fast_event()

          if refetch_err then
            console.debug.error(refetch_err).error(refetch_err)
            return
          end

          loop.await_fast_event()
          self.code_view:render()
        end, 100),
      },
      {
        mode = 'n',
        key = diff_preview:get('keymaps').buffer_unstage,
        vgit_key = string.format(
          'keys.%s',
          diff_preview:get('keymaps').buffer_unstage
        ),
        handler = loop.debounced_async(function()
          loop.await_fast_event()
          local _, filename = self.query:get_filename()
          loop.await_fast_event()

          if not filename then
            return
          end

          loop.await_fast_event()
          self.mutation:unstage_file(filename)
          loop.await_fast_event()

          loop.await_fast_event()
          local refetch_err = query:fetch(layout_type, buffer.filename, opts)
          loop.await_fast_event()

          if refetch_err then
            console.debug.error(refetch_err).error(refetch_err)
            return
          end

          loop.await_fast_event()
          self.code_view:render()
        end, 100),
      },
      {
        mode = 'n',
        key = diff_preview:get('keymaps').buffer_hunk_stage,
        vgit_key = string.format(
          'keys.%s',
          diff_preview:get('keymaps').buffer_hunk_stage
        ),
        handler = loop.debounced_async(function()
          if self.is_staged then
            return
          end

          loop.await_fast_event()
          local _, filename = self.query:get_filename()
          loop.await_fast_event()

          if not filename then
            return
          end

          loop.await_fast_event()
          local hunk, index = self.code_view:get_current_hunk_under_cursor()
          loop.await_fast_event()

          if not hunk then
            return
          end

          self.mutation:stage_hunk(filename, hunk)

          loop.await_fast_event()
          local refetch_err = query:fetch(layout_type, buffer.filename, opts)

          if refetch_err then
            console.debug.error(refetch_err).error(refetch_err)
            return
          end

          self.code_view:render():navigate_to_mark(index + 1, 'center')
        end, 100),
      },
      {
        mode = 'n',
        key = diff_preview:get('keymaps').buffer_hunk_unstage,
        vgit_key = string.format(
          'keys.%s',
          diff_preview:get('keymaps').buffer_hunk_unstage
        ),
        handler = loop.debounced_async(function()
          if not self.is_staged then
            return
          end

          loop.await_fast_event()
          local _, filename = self.query:get_filename()
          loop.await_fast_event()

          if not filename then
            return
          end

          loop.await_fast_event()
          local hunk, index = self.code_view:get_current_hunk_under_cursor()
          loop.await_fast_event()

          if not hunk then
            return
          end

          loop.await_fast_event()
          self.mutation:unstage_hunk(filename, hunk)
          loop.await_fast_event()

          loop.await_fast_event()
          local refetch_err = query:fetch(layout_type, buffer.filename, opts)
          loop.await_fast_event()

          if refetch_err then
            console.debug.error(refetch_err).error(refetch_err)
            return
          end

          loop.await_fast_event()
          self.code_view:render():navigate_to_mark(index + 1, 'center')
        end, 100),
      },
      {
        mode = 'n',
        key = '<enter>',
        vgit_key = 'keys.enter',
        handler = loop.debounced_async(function()
          loop.await_fast_event()
          local mark = self.code_view:get_current_mark_under_cursor()
          loop.await_fast_event()

          if not mark then
            return
          end

          loop.await_fast_event()
          local _, filename = self.query:get_filename()
          loop.await_fast_event()

          if not filename then
            return
          end

          self:destroy()
          loop.await_fast_event()

          fs.open(filename)

          loop.await_fast_event()
          Window(0):set_lnum(mark.top_relative):position_cursor('center')
        end, 100),
      },
      {
        mode = 'n',
        key = diff_preview:get('keymaps').toggle_view,
        vgit_key = string.format(
          'keys.%s',
          diff_preview:get('keymaps').toggle_view
        ),
        handler = loop.debounced_async(function()
          local is_staged = self.is_staged

          if is_staged then
            self.code_view:set_title('Diff')

            self.is_staged = false
            opts.is_staged = self.is_staged

            loop.await_fast_event()
            local refetch_err = query:fetch(layout_type, buffer.filename, opts)
            loop.await_fast_event()

            if refetch_err then
              console.debug.error(refetch_err).error(refetch_err)
              return
            end

            loop.await_fast_event()
            self.code_view:render()
          elseif not is_staged then
            self.code_view:set_title('Staged Diff')

            self.is_staged = true
            opts.is_staged = self.is_staged

            loop.await_fast_event()
            local refetch_err = query:fetch(layout_type, buffer.filename, opts)
            loop.await_fast_event()

            if refetch_err then
              console.debug.error(refetch_err).error(refetch_err)
              return
            end

            loop.await_fast_event()
            self.code_view:render()
          end
        end, 100),
      },
    })

  return true
end

function DiffScreen:destroy()
  self.scene:destroy()

  return self
end

return DiffScreen
