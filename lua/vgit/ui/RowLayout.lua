local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')

local RowLayout = Object:extend()

function RowLayout:constructor(...)
  return { views = { ... } }
end

function RowLayout:build()
  local row = 0
  local last_component

  for _, view in ipairs(self.views) do
    local plot
    local components = view:get_components()

    for _, component in ipairs(components) do
      plot = component:get_plot()

      plot.win_plot.row = plot.win_plot.row + row

      if plot.header_win_plot then
        plot.header_win_plot.row = plot.header_win_plot.row + row
      end
      if plot.footer_win_plot then
        plot.footer_win_plot.row = plot.footer_win_plot.row + row
      end

      last_component = component
    end

    row = row + plot.win_plot.height

    if plot.header_win_plot then
      row = row + plot.header_win_plot.height
    end
    if plot.footer_win_plot then
      row = row + plot.footer_win_plot.height
    end
  end

  local last_plot = last_component:get_plot()
  local global_height = dimensions.global_height()

  if last_plot.win_plot.row + last_plot.win_plot.height > global_height then
    row = dimensions.global_height() - last_plot.win_plot.height + 1

    if last_plot.header_win_plot then
      row = row - last_plot.header_win_plot.height
    end
    if last_plot.footer_win_plot then
      row = row - last_plot.footer_win_plot.height
    end

    for i = #self.views, 1, -1 do
      local plot
      local view = self.views[i]
      local components = view:get_components()

      for _, component in ipairs(components) do
        plot = component:get_plot()

        if i == #self.views then
          plot.win_plot.row = row

          if plot.header_win_plot then
            plot.header_win_plot.row = row
          end
          if plot.footer_win_plot then
            plot.footer_win_plot.row = row + plot.win_plot.height
          end
        else
          plot.win_plot.row = row - plot.win_plot.height - 1

          if plot.header_win_plot then
            plot.header_win_plot.row = row - plot.win_plot.height - 1
          end
          if plot.footer_win_plot then
            plot.footer_win_plot.row = row - 1
          end
        end
      end

      row = plot.win_plot.row
    end
  end

  return self
end

return RowLayout
