local lazy = require('vgit.core.lazy')
local Component = lazy('vgit.ui.Component')
local Element = lazy('vgit.ui.elements.Element')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')

local BlameInfoComponent = Component:extend()

function BlameInfoComponent:constructor(props)
  return Component.constructor(self, props)
end

function BlameInfoComponent:get_initial_state()
  return {
    blame = nil,
  }
end

function BlameInfoComponent:component_will_mount()
  self._element = Element({
    buf_options = {
      modifiable = false,
      buflisted = false,
      bufhidden = 'wipe',
    },
    win_options = {
      winhl = 'Normal:GitBackground',
      cursorline = false,
      wrap = false,
    },
  })
end

function BlameInfoComponent:render()
  if not self._element or not self._element:is_valid() then return end

  local blame = self.props.blame
  if blame then
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

    self._element._buffer:set_lines(lines)

    self._element:clear_extmarks()

    if lines[1]:match('^[a-f0-9]+%s*%->%s*[a-f0-9]+$') then
      self._element:place_extmark_highlight({
        hl = 'Character',
        pattern = '^([a-f0-9]+)',
        row = 0,
      })
      self._element:place_extmark_highlight({
        hl = 'Constant',
        pattern = '([a-f0-9]+)$',
        row = 0,
      })
    else
      self._element:place_extmark_highlight({
        hl = 'Constant',
        row = 0,
        col_range = {
          from = 0,
          to = #lines[1],
        },
      })
    end

    self._element:place_extmark_text({
      text = string.format('%s (%s)', blame:age().display, os.date('%c', blame.author_time)),
      hl = 'GitComment',
      row = 1,
      col = 0,
      pos = 'eol',
    })
  end
end

function BlameInfoComponent:get_layout_spec()
  return LayoutSpec.view(self._element, { height = 3 })
end

function BlameInfoComponent:component_did_mount()
  self:render()
end

function BlameInfoComponent:unmount()
  if not self._mounted then return end

  self._element:unmount()
  self._element = nil

  Component.unmount(self)
end

return BlameInfoComponent
