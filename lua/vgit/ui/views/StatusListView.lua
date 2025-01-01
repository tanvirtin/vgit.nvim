local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local StatusListGenerator = require('vgit.ui.StatusListGenerator')
local FoldableListComponent = require('vgit.ui.components.FoldableListComponent')

local StatusListView = Object:extend()

function StatusListView:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    state = {
      title = '',
      folds = nil,
    },
    config = config or {},
    event_handlers = {
      on_enter = function(row) end,
      on_move = function(lnum) end,
    },
  }
end

function StatusListView:get_components()
  return { self.scene:get('list') }
end

function StatusListView:define()
  self.scene:set(
    'list',
    FoldableListComponent({
      config = {
        elements = utils.object.assign({
          header = true,
          footer = false,
        }, self.config.elements),
        win_plot = dimensions.relative_win_plot(self.plot, {
          height = '100vh',
          width = '100vw',
        }),
        win_options = {
          cursorline = true,
        },
      },
    })
  )
end

function StatusListView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene:get('list'):set_keymap(config.mode, config.key, config.handler)
  end)
end

function StatusListView:set_title(text)
  self.state.title = text
end

function StatusListView:get_list_item(lnum)
  return self.scene:get('list'):get_list_item(lnum)
end

function StatusListView:find_list_item(callback)
  return self.scene:get('list'):find_list_item(callback)
end

function StatusListView:each_list_item(callback)
  local component = self.scene:get('list')
  component:each_list_item(callback)
end

function StatusListView:find_status(callback)
  return self:find_list_item(function(node, lnum)
    local status = node.path and node.path.status or nil
    if not status then return false end
    local entry_type = node.path.type
    return callback(status, entry_type, lnum) == true
  end)
end

function StatusListView:each_status(callback)
  local component = self.scene:get('list')
  component:each_list_item(function(node, lnum)
    local status = node.path and node.path.status or nil
    if not status then return false end
    local entry_type = node.path.type
    callback(status, entry_type, lnum)
  end)
end

function StatusListView:move_to(callback)
  local component = self.scene:get('list')
  local status, lnum = self:find_status(callback)
  if not status then return end

  component:unlock():set_lnum(lnum):lock()

  return status
end

function StatusListView:get_current_list_item()
  local component = self.scene:get('list')
  local lnum = component:get_lnum()

  return self:get_list_item(lnum)
end

function StatusListView:move(direction)
  local component = self.scene:get('list')
  local lnum = component:get_lnum()
  local count = component:get_line_count()

  if direction == 'down' then lnum = lnum + 1 end
  if direction == 'up' then lnum = lnum - 1 end

  if lnum < 1 then
    lnum = count
  elseif lnum > count then
    lnum = 1
  end

  component:unlock():set_lnum(lnum):lock()

  return self:get_list_item(lnum)
end

function StatusListView:toggle_current_list_item()
  local lnum = self.scene:get('list'):get_lnum()
  local item = self:get_list_item(lnum)

  if item and item.open ~= nil then
    item.open = not item.open
  end

  local component = self.scene:get('list')
  component:unlock()
    :set_title(self.state.title)
    :set_list(self.state.folds)
    :sync()
    :lock()
end

function StatusListView:render()
  local entries = self.props.entries()

  local folds = {}
  for category in pairs(entries) do
    local entry = entries[category]
    folds[#folds + 1] = {
      open = true,
      value = category,
      items = StatusListGenerator(entry):generate({ category = category }),
    }
  end

  self.state.folds = folds

  local component = self.scene:get('list')
  component:unlock():set_title(self.state.title):set_list(folds):sync():lock()
end

function StatusListView:mount(opts)
  local component = self.scene:get('list')
  component:mount(opts)

  if opts.event_handlers then
    self.event_handlers = utils.object.assign(self.event_handlers, opts.event_handlers)
  end

  self:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local item = self:get_current_list_item()
        if not item then return end
        self.event_handlers.on_enter(item)
      end),
    },
  })

  component:on('CursorMoved', function ()
    local item = self:move()
    self.event_handlers.on_move(item)
  end)
end

return StatusListView
