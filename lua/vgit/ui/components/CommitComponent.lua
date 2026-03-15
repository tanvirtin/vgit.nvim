local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')
local Element = lazy('vgit.ui.elements.Element')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')

local CommitComponent = Component:extend()

function CommitComponent:constructor(props)
  return Component.constructor(self, props)
end

function CommitComponent:component_will_mount()
  if not self._element then
    self._element = Element({
      buf_options = {
        modifiable = true,
        buflisted = false,
        bufhidden = 'wipe',
        buftype = 'nofile',
        filetype = self.props.filetype or 'gitcommit',
      },
      win_options = {
        number = false,
        relativenumber = false,
        signcolumn = 'no',
        wrap = true,
        cursorline = true,
      },
    })
  end
end

function CommitComponent:component_did_mount()
  local confirm_key = self.props.confirm_key or '<C-s>'
  local cancel_key = self.props.cancel_key or 'q'

  self:with_element(function(el)
    el:set_keymap({ mode = { 'n', 'i' }, key = confirm_key, desc = 'Confirm commit' }, function()
      if self.props.on_confirm then self.props.on_confirm() end
    end)

    el:set_keymap('n', cancel_key, function()
      if self.props.on_cancel then self.props.on_cancel() end
    end, 'Cancel commit')
  end)

  self:render()
end

function CommitComponent:render() end

function CommitComponent:get_layout_spec()
  return LayoutSpec.view(self._element, { flex = 1 })
end

function CommitComponent:get_lines()
  return self:with_element(function(el)
    return el:get_lines()
  end) or {}
end

function CommitComponent:set_lines(lines)
  self:with_element(function(el)
    el:set_lines(lines)
  end)
  return self
end

function CommitComponent:focus()
  self:with_element(function(el)
    el:focus()
  end)
  return self
end

function CommitComponent:set_cursor(cursor)
  self:with_element(function(el)
    el:set_cursor(cursor)
  end)
  return self
end

function CommitComponent:is_valid()
  return self:with_element(function()
    return true
  end) or false
end

function CommitComponent:unmount()
  if not self._mounted then return end

  if self._element then
    self._element:unmount()
    self._element = nil
  end

  Component.unmount(self)
end

return CommitComponent
