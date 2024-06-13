local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local dimensions = require('vgit.ui.dimensions')
local FoldableListComponent = require('vgit.ui.components.FoldableListComponent')

local FoldableListView = Object:extend()

function FoldableListView:constructor(scene, store, plot, config)
  return {
    title = '',
    scene = scene,
    store = store,
    plot = plot,
    config = config or {},
  }
end

function FoldableListView:get_components()
  return { self.scene:get('list') }
end

function FoldableListView:define()
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

  return self
end

function FoldableListView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene:get('list'):set_keymap(config.mode, config.key, config.handler)
  end)

  return self
end

function FoldableListView:set_title(text)
  self.title = text
  return self
end

function FoldableListView:evict_cache()
  self.store:set_list_folds(nil)
  return self
end

function FoldableListView:get_list()
  local list = self.store:get_list_folds()
  if list then return list end

  local data, err = self.store:get_all()
  if err then
    console.debug.error(err).error(err)
    return {}
  end

  list = self.config.get_list(data)
  self.store:set_list_folds(list)

  return list
end

function FoldableListView:get_list_item(lnum)
  return self.scene:get('list'):get_list_item(lnum)
end

function FoldableListView:get_current_list_item()
  return self:get_list_item(self.scene:get('list'):get_lnum())
end

function FoldableListView:query_list_item(callback)
  return self.scene:get('list'):query_list_item(callback)
end

function FoldableListView:toggle_current_list_item()
  local item = self:get_list_item(self.scene:get('list'):get_lnum())
  if item and item.open ~= nil then item.open = not item.open end

  return self
end

function FoldableListView:move_to(callback)
  local list = self.scene:get('list')
  local item, lnum = list:find_list_item(callback)
  if not item then return end

  list:unlock():set_lnum(lnum):lock()
  self.store:set_lnum(lnum)

  return item
end

function FoldableListView:move(direction)
  local list = self.scene:get('list')
  local lnum = list:get_lnum()
  local count = list:get_line_count()

  if direction == 'down' then lnum = lnum + 1 end
  if direction == 'up' then lnum = lnum - 1 end

  if lnum < 1 then
    lnum = count
  elseif lnum > count then
    lnum = 1
  end

  list:unlock():set_lnum(lnum):lock()
  self.store:set_lnum(lnum)

  return self:get_list_item(lnum)
end

function FoldableListView:render()
  self:evict_cache()

  local lnum = self.store:get_lnum()
  local list = self.scene:get('list')

  loop.free_textlock()
  local parsed_list = self:get_list()
  loop.free_textlock()

  list:unlock():set_title(self.title):set_list(parsed_list):sync():set_lnum(lnum):lock()
  loop.free_textlock()

  return self
end

function FoldableListView:mount(opts)
  self.scene:get('list'):mount(opts)
  return self
end

function FoldableListView:show(opts)
  self:mount(opts):render()
  return self
end

return FoldableListView
