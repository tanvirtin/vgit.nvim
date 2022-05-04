local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local dimensions = require('vgit.ui.dimensions')
local FoldableListComponent = require(
  'vgit.ui.components.FoldableListComponent'
)

local FoldableListView = Object:extend()

function FoldableListView:constructor(scene, query, plot, config)
  return {
    scene = scene,
    query = query,
    plot = plot,
    config = config or {},
    _cache = {},
  }
end

function FoldableListView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene
      :get('list')
      :set_keymap(config.mode, config.key, config.vgit_key, config.handler)
  end)

  return self
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
      },
    })
  )

  return self
end

function FoldableListView:evict_cache()
  self._cache['list'] = nil

  return self
end

function FoldableListView:get_list()
  if self._cache['list'] then
    return self._cache['list']
  end

  local err, data = self.query:get_all()

  if err then
    console.debug.error(err).error(err)
    return {}
  end

  self._cache['list'] = self.config.get_list(data)

  return self._cache['list']
end

function FoldableListView:get_list_item(lnum)
  return self.scene:get('list'):get_list_item(lnum)
end

function FoldableListView:get_current_list_item()
  return self:get_list_item(self.scene:get('list'):get_lnum())
end

function FoldableListView:toggle_current_list_item()
  local item = self:get_list_item(self.scene:get('list'):get_lnum())

  if item and item.open ~= nil then
    item.open = not item.open
  end

  return self
end

function FoldableListView:move(direction)
  local component = self.scene:get('list')
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

  return self:get_list_item(lnum)
end

function FoldableListView:render()
  local list = self.scene:get('list')

  loop.await_fast_event()
  local parsed_list = self:get_list()
  loop.await_fast_event()

  list:unlock():set_list(parsed_list):sync():lock()
  loop.await_fast_event()

  return self
end

function FoldableListView:mount_scene(mount_opts)
  self.scene:get('list'):mount(mount_opts)

  return self
end

function FoldableListView:show(mount_opts)
  self._cache = {}

  self:define():mount_scene(mount_opts):render()

  return self
end

return FoldableListView
