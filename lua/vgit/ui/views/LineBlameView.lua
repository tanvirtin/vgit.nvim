local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local LineBlameView = Object:extend()

function LineBlameView:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    config = config or {},
  }
end

function LineBlameView:define()
  self.scene:set(
    'line_blame',
    PresentationalComponent({
      config = {
        elements = { header = true, footer = false },
        win_plot = dimensions.relative_win_plot(self.plot, { height = '100vh', width = '100vw' }),
      },
    })
  )
end

function LineBlameView:get_components()
  return { self.scene:get('line_blame') }
end

function LineBlameView:set_keymap(configs)
  local component = self.scene:get('line_blame')
  utils.list.each(configs, function(config)
    component:set_keymap(config, config.handler)
  end)
end

function LineBlameView:mount(opts)
  local component = self.scene:get('line_blame')
  component:mount(opts)
end

function LineBlameView:render()
  local blame, err = self.props.blame()
  if err then return end

  local component = self.scene:get('line_blame')
  local max_line_length = 88
  local commit_message = blame.commit_message

  if #commit_message > max_line_length then commit_message = commit_message:sub(1, max_line_length) .. '...' end

  local commit_details = blame.commit_hash
  if blame.parent_hash then commit_details = string.format('%s -> %s', blame.parent_hash, blame.commit_hash) end

  local lines = {
    commit_details,
    string.format('%s (%s)', blame.author, blame.author_mail),
    string.format('%s', commit_message),
  }

  component:unlock():set_lines(lines):lock()
  component:clear_extmarks()

  if lines[1]:match('^[a-f0-9]+%s*%->%s*[a-f0-9]+$') then
    component:place_extmark_highlight({
      hl = 'Character',
      pattern = '^([a-f0-9]+)',
      row = 0,
    })
    component:place_extmark_highlight({
      hl = 'Constant',
      pattern = '([a-f0-9]+)$',
      row = 0,
    })
  else
    component:place_extmark_highlight({
      hl = 'Constant',
      row = 0,
      col_range = {
        from = 0,
        to = #lines[1],
      },
    })
  end
  component:place_extmark_text({
    text = string.format('%s (%s)', blame:age().display, os.date('%c', blame.author_time)),
    hl = 'GitComment',
    row = 1,
    col = 0,
    pos = 'eol',
  })
end

return LineBlameView
