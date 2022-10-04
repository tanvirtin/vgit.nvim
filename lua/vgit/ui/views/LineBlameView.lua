local utils = require('vgit.core.utils')
local dimensions = require('vgit.ui.dimensions')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local LineBlameView = Object:extend()

function LineBlameView:constructor(scene, store, plot, config)
  return {
    scene = scene,
    store = store,
    plot = plot,
    config = config or {},
  }
end

function LineBlameView:define()
  self.scene:set(
    'current',
    PresentationalComponent({
      config = {
        elements = {
          header = true,
          footer = true,
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

function LineBlameView:set_keymap(configs)
  utils.list.each(
    configs,
    function(config) self.scene:get('current'):set_keymap(config.mode, config.key, config.handler) end
  )
  return self
end

function LineBlameView:create_uncommitted_lines(blame)
  return {
    string.format('%s', 'Uncommitted changes'),
    '',
    '',
    string.format('%s -> %s', blame.parent_hash, blame.commit_hash),
  }
end

function LineBlameView:create_committed_lines(blame)
  local max_line_length = 88
  local commit_message = blame.commit_message
  if #commit_message > max_line_length then
    commit_message = commit_message:sub(1, max_line_length) .. '...'
  end
  return {
    string.format('%s (%s)', blame.author, blame.author_mail),
    string.format('%s (%s)', blame:age().display, os.date('%c', blame.author_time)),
    string.format('%s', commit_message),
    string.format('%s -> %s', blame.parent_hash, blame.commit_hash),
  }
end

function LineBlameView:render()
  local err, blame = self.store:get_blame()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  self.scene
    :get('current')
    :unlock()
    :set_lines(blame.committed and self:create_committed_lines(blame) or self:create_uncommitted_lines(blame))
    :focus()
    :lock()

  return self
end

function LineBlameView:mount(opts)
  self.scene:get('current'):mount(opts)

  return self
end

function LineBlameView:show(opts)
  self:define():mount(opts):render()

  return self
end

return LineBlameView
