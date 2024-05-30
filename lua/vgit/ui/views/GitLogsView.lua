local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local Namespace = require('vgit.core.Namespace')
local dimensions = require('vgit.ui.dimensions')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')
local TableGenerator = require('vgit.ui.TableGenerator')

local GitLogsView = Object:extend()

function GitLogsView:constructor(scene, store, plot, config)
  return {
    scene = scene,
    store = store,
    plot = plot,
    config = config or {},
    namespace = Namespace(),
    state = {
      selected = {},
    },
  }
end

function GitLogsView:get_components() return { self.scene:get('selectable_view') } end

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
  utils.list.each(
    configs,
    function(config) self.scene:get('selectable_view'):set_keymap(config.mode, config.key, config.handler) end
  )
  return self
end

function GitLogsView:render_title(labels)
  self.scene:get('selectable_view'):set_title(labels[1])

  return self
end

function GitLogsView:select()
  local component = self.scene:get('selectable_view')
  local buffer = component.buffer
  local lnum = component:get_lnum()

  if self.state.selected[lnum] then
    self.state.selected[lnum] = nil

    self.namespace:clear(buffer, {
      from = lnum - 1,
      to = lnum
    })

    return self
  end

  self.state.selected[lnum] = true

  self.namespace:add_highlight(buffer, {
    hl = 'GitSelected',
    row = lnum - 1,
    col_range = {
      from = 1,
      to = 41
    }
  })
  return self
end

function GitLogsView:has_selection() return not utils.object.is_empty(self.state.selected) end

function GitLogsView:get_selected()
  local err, data = self.store:get_data()

  if err then
    console.debug.error(err)
    return {}
  end

  return utils.list.filter(data, function(_, index) return self.state.selected[index] == true end)
end

function GitLogsView:paint()
  local component = self.scene:get('selectable_view')
  local num_lines = component:get_line_count()

  for i = 1, num_lines do
    component:add_highlight({
      hl = 'Constant',
      row = i - 1,
      col_range = {
        from = 0,
        to = 41
      }
    })
  end

  return self
end

function GitLogsView:render()
  local err, logs = self.store:get_data()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  local labels, rows, _ = TableGenerator(
    {
      'Commit',
      'Author',
      'Date',
      'Summary',
    },
    utils.list.map(logs, function(log)
      local time = utils.date.format(log.timestamp)

      return { log.commit_hash, log.author_name, time, log.summary }
    end),
    1,
    80
  ):generate()

  self:render_title(labels)

  self.scene:get('selectable_view'):unlock():set_lines(rows):focus():lock()

  return self:paint()
end

function GitLogsView:mount(opts)
  self.scene:get('selectable_view'):mount(opts)

  return self
end

function GitLogsView:show(opts)
  self:mount(opts):render()

  return self
end

return GitLogsView
