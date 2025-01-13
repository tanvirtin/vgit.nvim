local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local TableComponent = require('vgit.ui.components.TableComponent')

local TableView = Object:extend()

function TableView:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    state = { lnum = 1 },
    config = config or {},
    event_handlers = {
      on_enter = function(row) end,
      on_move = function(lnum) end,
    },
  }
end

function TableView:get_components()
  return { self.scene:get('table') }
end

function TableView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene:get('table'):set_keymap(config.mode, config.key, config.handler)
  end)
end

function TableView:define()
  local component = TableComponent({
    config = {
      column_labels = self.props.column_labels(),
      elements = utils.object.assign({
        header = true,
        footer = false,
      }, self.config.elements),
      win_plot = dimensions.relative_win_plot(self.plot, {
        height = '100vh',
        width = '100vw',
      }),
    },
  })
  self.scene:set('table', component)
end

function TableView:move(direction)
  local component = self.scene:get('table')
  local lnum = component:get_lnum()
  local count = component:get_line_count()

  if direction == 'down' then lnum = lnum + 1 end
  if direction == 'up' then lnum = lnum - 1 end
  if lnum < 1 then
    lnum = count
  elseif lnum > count then
    lnum = 1
  end

  self.state.lnum = lnum
  component:unlock():set_lnum(lnum):lock()

  return lnum
end

function TableView:get_current_row()
  local entries = self.props.entries()
  if not entries then return nil end

  local component = self.scene:get('table')
  local lnum = component:get_lnum()

  return entries[lnum]
end

function TableView:render()
  local entries = self.props.entries()
  if not entries then return end

  self.scene:get('table'):unlock():render_rows(entries, self.props.row):focus():set_lnum(self.state.lnum):lock()
end

function TableView:mount(opts)
  local component = self.scene:get('table')
  component:mount(opts)

  if opts.event_handlers then self.event_handlers = utils.object.assign(self.event_handlers, opts.event_handlers) end

  self:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local row = self:get_current_row()
        if not row then return end
        self.event_handlers.on_enter(row)
      end),
    },
  })

  component:on('CursorMoved', function()
    local lnum = self:move()
    self.event_handlers.on_move(lnum)
  end)
end

return TableView
