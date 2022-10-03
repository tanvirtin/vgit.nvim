local utils = require('vgit.core.utils')
local dimensions = require('vgit.ui.dimensions')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local GutterBlameView = Object:extend()

function GutterBlameView:constructor(scene, store, plot, config)
  return {
    scene = scene,
    store = store,
    plot = plot,
    config = config or {},
  }
end

function GutterBlameView:define()
  self.scene:set(
    'gutter_blame',
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

function GutterBlameView:set_keymap(configs)
  utils.list.each(
    configs,
    function(config) self.scene:get('gutter_blame'):set_keymap(config.mode, config.key, config.handler) end
  )
  return self
end

function GutterBlameView:render()
  local err, blames = self.store:get_blames()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  self.scene
    :get('gutter_blame')
    :unlock()
    :set_lines(utils.list.map(blames, function(blame)
      if blame.committed then
        return string.format(
          '%s %s (%s) %s',
          blame.commit_hash:sub(1, 8),
          blame.author,
          blame:age().display,
          blame.committed and blame.commit_message or 'Uncommitted changes'
        )
      end
      return 'Uncommitted changes'
    end))
    :focus()
    :lock()

  return self
end

function GutterBlameView:mount(opts)
  self.scene:get('gutter_blame'):mount(opts)

  return self
end

function GutterBlameView:show(opts)
  self:define():mount(opts):render()

  return self
end

return GutterBlameView
