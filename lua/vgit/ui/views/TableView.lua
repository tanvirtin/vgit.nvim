local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local TableGenerator = require('vgit.ui.TableGenerator')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local TableView = Object:extend()

function TableView:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    state = { entries = {} },
    config = config or {},
    event_handlers = {
      on_select = function(entry) end,
    },
  }
end

function TableView:define()
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

function TableView:set_keymap(configs)
  utils.list.each(configs, function(config)
    local component = self.scene:get('selectable_view')
    component:set_keymap(config, config.handler)
  end)
end

function TableView:render_title(labels)
  local component = self.scene:get('selectable_view')
  local label = labels[1]
  component:set_title(label)
end

function TableView:mount(opts)
  opts = opts or {}

  local component = self.scene:get('selectable_view')
  component:mount(opts)

  if opts.event_handlers then self.event_handlers = utils.object.assign(self.event_handlers, opts.event_handlers) end

  self:set_keymap({
    {
      mode = 'n',
      key = '<tab>',
      handler = loop.coroutine(function()
        local lnum = component:get_lnum()
        local entry = self.state.entries[lnum]
        if not entry then return end
        self.event_handlers.on_select(entry)
        self:render()
      end),
    },
  })
end

function TableView:generate_table(entries)
  local headers = self.props.headers()
  local header_captions = utils.list.map(headers, function(header)
    return header.caption
  end)
  local header_names = utils.list.map(headers, function(header)
    return header.name
  end)

  local row_mappings = utils.list.map(entries, function(entry)
    return utils.list.map(header_names, function(header_name)
      return entry[header_name]
    end)
  end)

  self.state.entries = entries

  return TableGenerator(header_captions, row_mappings, 1, 80):generate()
end

function TableView:render()
  local entries = self.props.entries()
  if not entries or #entries == 0 then return end

  local labels, rows = self:generate_table(entries)
  self:render_title(labels)

  local component = self.scene:get('selectable_view')
  component:unlock():set_lines(rows):focus():lock()

  local num_lines = component:get_line_count()

  for lnum = 1, num_lines do
    local entry = self.state.entries[lnum]
    local is_selected = self.props.is_selected(entry)

    component:place_extmark_highlight({
      hl = is_selected and 'Keyword' or 'Constant',
      row = lnum - 1,
      col_range = {
        from = 0,
        to = 41,
      },
    })
  end
end

return TableView
