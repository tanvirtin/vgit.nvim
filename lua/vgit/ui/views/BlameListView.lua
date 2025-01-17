local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local BlameListView = Object:extend()

function BlameListView:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    state = { lnum = 1 },
    config = config or {},
    event_handlers = {
      on_enter = function(row) end,
      on_move = function(lnum) end,
    },
  }
end

function BlameListView:define()
  local component = PresentationalComponent({
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
  self.scene:set('list', component)
end

function BlameListView:get_component()
  return self.scene:get('list')
end

function BlameListView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self:get_component():set_keymap(config.mode, config.key, config.handler)
  end)
end

function BlameListView:move(direction)
  local component = self:get_component()
  local lnum = component:get_lnum()
  local count = component:get_line_count()

  if direction == 'down' then lnum = lnum + 1 end
  if direction == 'up' then lnum = lnum - 1 end
  if lnum < 1 then
    lnum = count
  elseif lnum > count then
    lnum = 1
  end

  self.state.lnum = lnum
  component:unlock():set_lnum(lnum):lock()

  return lnum
end

function BlameListView:get_current_row()
  local entries = self.props.entries()
  if not entries then return nil end

  local component = self.scene:get('list')
  local lnum = component:get_lnum()

  return entries[lnum]
end

function BlameListView:mount(opts)
  local component = self:get_component()
  component:mount(opts)

  if opts.event_handlers then self.event_handlers = utils.object.assign(self.event_handlers, opts.event_handlers) end

  self:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local row = self:get_current_row()
        if not row then return end
        self.event_handlers.on_enter(row)
      end),
    },
  })
  component:on('CursorMoved', function()
    local lnum = self:move()
    self.event_handlers.on_move(lnum)
  end)
end

function BlameListView:render()
  local entries = self.props.entries()
  if not entries then return end

  local config = self.props.config()
  if not config then return end

  local lines = {}
  local highlight_groups = {}

  utils.list.each(entries, function(entry)
    local config_author = config['user.name']
    local commit_hash = entry.commit_hash:sub(1, 7)

    local author = entry.author_name
    if config_author == author then author = 'You' end

    local max_len = 255
    local commit_message = entry.summary
    if #commit_message > max_len then commit_message = commit_message:sub(1, max_len) .. '...' end

    local age = entry:age().display

    local line = string.format('%s %s %s • %s', commit_hash, commit_message, author, age)
    lines[#lines + 1] = line
    highlight_groups[#highlight_groups + 1] = {
      {
        hl = 'Keyword',
        col_range = { from = 0, to = #commit_hash },
      },
      {
        hl = 'Comment',
        col_range = {
          from = #commit_hash + 1 + #commit_message + 1,
          to = #line,
        },
      },
    }
  end)

  local component = self:get_component()
  component:unlock():set_lines(lines)

  utils.list.each(highlight_groups, function(highlights, row)
    utils.list.each(highlights, function(highlight)
      component:place_extmark_highlight({
        row = row - 1,
        hl = highlight.hl,
        col_range = highlight.col_range,
      })
    end)
  end)

  component:focus():set_lnum(self.state.lnum):lock()
end

return BlameListView
