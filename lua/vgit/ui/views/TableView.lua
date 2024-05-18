local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local dimensions = require('vgit.ui.dimensions')
local TableComponent = require('vgit.ui.components.TableComponent')

local TableView = Object:extend()

function TableView:constructor(scene, store, plot, config)
  return {
    scene = scene,
    store = store,
    plot = plot,
    config = config or {},
  }
end

function TableView:get_components() return { self.scene:get('table') } end

function TableView:set_keymap(configs)
  utils.list.each(
    configs,
    function(config) self.scene:get('table'):set_keymap(config.mode, config.key, config.handler) end
  )
  return self
end

function TableView:define()
  self.scene:set(
    'table',
    TableComponent({
      config = {
        column_labels = self.config.column_labels,
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
  )
  return self
end

function TableView:move(direction)
  local component = self.scene:get('table')
  local lnum = component:get_lnum()
  local count = component:get_line_count()

  if direction == 'down' then
    lnum = lnum + 1
  end
  if direction == 'up' then
    lnum = lnum - 1
  end
  if lnum < 1 then
    lnum = count
  elseif lnum > count then
    lnum = 1
  end

  component:unlock():set_lnum(lnum):lock()
  self.store:set_lnum(lnum)

  return lnum
end

function TableView:get_current_row()
  local _, entries = self.store:get_all()

  if not entries then
    return nil
  end

  return entries[self.scene:get('table'):get_lnum()]
end

function TableView:render()
  local _, lnum = self.store:get_lnum()
  local err, entries = self.store:get_all()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  self.scene:get('table'):unlock():render_rows(entries, self.config.get_row):focus():set_lnum(lnum):lock()

  return self
end

function TableView:mount(opts)
  self.scene:get('table'):mount(opts)

  return self
end

function TableView:show(opts)
  self:mount(opts):render()

  return self
end

return TableView
