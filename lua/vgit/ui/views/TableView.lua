local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local dimensions = require('vgit.ui.dimensions')
local TableComponent = require('vgit.ui.components.TableComponent')

local TableView = Object:extend()

function TableView:constructor(scene, query, plot, config)
  return {
    scene = scene,
    query = query,
    plot = plot,
    config = config or {},
  }
end

function TableView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene
      :get('table')
      :set_keymap(config.mode, config.key, config.vgit_key, config.handler)
  end)
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
          row = '0vh',
          col = '0vw',
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

  return lnum
end

function TableView:render()
  local err, entries = self.query:get_all()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  self.scene
    :get('table')
    :unlock()
    :make_rows(entries, self.config.on_row)
    :focus()
    :lock()

  return self
end

function TableView:mount_scene(mount_opts)
  self.scene:get('table'):mount(mount_opts)

  return self
end

function TableView:show(mount_opts)
  self:define():mount_scene(mount_opts):render()

  return self
end

return TableView
