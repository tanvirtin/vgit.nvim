local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local TableGenerator = require('vgit.ui.TableGenerator')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local GitLogsView = Object:extend()

function GitLogsView:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    config = config or {},
    state = { selected = {} },
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
end

function GitLogsView:set_keymap(configs)
  utils.list.each(configs, function(config)
    local component = self.scene:get('selectable_view')
    component:set_keymap(config.mode, config.key, config.handler)
  end)
end

function GitLogsView:render_title(labels)
  local component = self.scene:get('selectable_view')
  local label = labels[1]
  component:set_title(label)
end

function GitLogsView:select()
  local component = self.scene:get('selectable_view')
  local lnum = component:get_lnum()

  if self.state.selected[lnum] then
    self.state.selected[lnum] = nil
    return
  end

  self.state.selected[lnum] = true
end

function GitLogsView:has_selection()
  return not utils.object.is_empty(self.state.selected)
end

function GitLogsView:get_selected()
  local logs = self.props.logs()
  if not logs then return {} end

  return utils.list.filter(logs, function(_, index)
    return self.state.selected[index] == true
  end)
end

function GitLogsView:paint()
  local component = self.scene:get('selectable_view')
  local num_lines = component:get_line_count()

  for i = 1, num_lines do
    component:place_extmark_highlight({
      hl = 'Constant',
      row = i - 1,
      col_range = {
        from = 0,
        to = 41,
      },
    })
  end
end

function GitLogsView:render()
  local logs = self.props.logs()
  if not logs then return end

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

  local component = self.scene:get('selectable_view')
  component:unlock():set_lines(rows):focus():lock()

  self:paint()
end

function GitLogsView:mount(opts)
  local component = self.scene:get('selectable_view')
  component:mount(opts)
end

return GitLogsView
