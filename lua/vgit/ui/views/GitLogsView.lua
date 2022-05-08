local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local Namespace = require('vgit.core.Namespace')
local dimensions = require('vgit.ui.dimensions')
local PresentationalComponent = require(
  'vgit.ui.components.PresentationalComponent'
)

local GitLogsView = Object:extend()

function GitLogsView:constructor(scene, query, plot, config)
  return {
    scene = scene,
    query = query,
    plot = plot,
    config = config or {},
    namespace = Namespace(),
    state = {
      selected = {},
    },
  }
end

function GitLogsView:define()
  self.scene:set(
    'selectable_view',
    PresentationalComponent({
      config = {
        elements = utils.object.assign({
          header = true,
          footer = false,
        }, self.config.elements),
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = dimensions.relative_win_plot(self.plot, {
          height = '100vh',
          width = '100vw',
        }),
      },
    })
  )
  return self
end

function GitLogsView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene
      :get('selectable_view')
      :set_keymap(config.mode, config.key, config.vgit_key, config.handler)
  end)
  return self
end

function GitLogsView:set_title()
  local _, title = self.query:get_title()

  self.scene:get('selectable_view'):set_title(title)

  return self
end

function GitLogsView:select()
  local component = self.scene:get('selectable_view')
  local buffer = component.buffer
  local lnum = component:get_lnum()

  if self.state.selected[lnum] then
    self.state.selected[lnum] = nil

    self.namespace:clear(buffer, lnum - 1, lnum)
    return self
  end

  self.state.selected[lnum] = true

  self.namespace:add_highlight(buffer, 'GitSelected', lnum - 1, 0, 40)
  return self
end

function GitLogsView:get_selected()
  local err, data = self.query:get_data()

  if err then
    console.debug.error(err)
    return {}
  end

  return utils.list.filter(data, function(_, index)
    return self.state.selected[index] == true
  end)
end

function GitLogsView:paint()
  local component = self.scene:get('selectable_view')
  local num_lines = component:get_line_count()

  for i = 1, num_lines do
    component:add_highlight('TODO', i - 1, 0, 40)
  end

  return self
end

function GitLogsView:render()
  local err, lines = self.query:get_lines()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  self:set_title()
  self.scene:get('selectable_view'):unlock():set_lines(lines):focus():lock()

  return self:paint()
end

function GitLogsView:mount_scene(mount_opts)
  self.scene:get('selectable_view'):mount(mount_opts)

  return self
end

function GitLogsView:show(mount_opts)
  self:define():mount_scene(mount_opts):render()

  return self
end

return GitLogsView
