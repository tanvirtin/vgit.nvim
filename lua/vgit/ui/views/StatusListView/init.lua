local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local StatusFolds = require('vgit.ui.views.StatusListView.StatusFolds')
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
    self.scene:get('list'):set_keymap(config, config.handler)
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
    local status = node.entry and node.entry.status or nil
    if not status then return false end
    local entry_type = node.entry.type
    return callback(status, entry_type, lnum) == true
  end)
end

function StatusListView:each_status(callback)
  local component = self.scene:get('list')
  component:each_list_item(function(node, lnum)
    local status = node.entry and node.entry.status or nil
    if not status then return false end
    local entry_type = node.entry.type
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

  if item and item.open ~= nil then item.open = not item.open end

  local component = self.scene:get('list')
  component:unlock():set_title(self.state.title):set_list(self.state.folds):sync():lock()
end

function StatusListView:mount(opts)
  local component = self.scene:get('list')
  component:mount(opts)

  if opts.event_handlers then self.event_handlers = utils.object.assign(self.event_handlers, opts.event_handlers) end

  self:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      desc = 'Enter item',
      handler = loop.coroutine(function()
        local item = self:get_current_list_item()
        if not item then return end
        self:toggle_current_list_item()
        self.event_handlers.on_enter(item)
      end),
    },
  })

  component:on('CursorMoved', function()
    local item = self:move()
    self.event_handlers.on_move(item)
  end)
end

function StatusListView:render()
  local entries = self.props.entries()
  if not entries then return end

  local open = true
  local open_folds = self.config.open_folds
  if open_folds ~= nil then open = open_folds end

  local folds = {}
  for _, entry in ipairs(entries) do
    folds[#folds + 1] = {
      open = open,
      value = entry.title,
      metadata = entry.metadata,
      items = StatusFolds(entry.metadata):generate(entry.entries),
    }
  end

  self.state.folds = folds

  local component = self.scene:get('list')
  component:unlock():set_title(self.state.title):set_list(folds):sync():lock()
end

return StatusListView
