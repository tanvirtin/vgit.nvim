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
    local buf_options = {
      modifiable = true,
      buflisted = false,
      bufhidden = 'wipe',
      buftype = 'nofile',
      filetype = self.props.filetype or 'gitcommit',
    }

    local win_options = {
      number = false,
      relativenumber = false,
      signcolumn = 'no',
      wrap = true,
      cursorline = true,
    }

    self._element = Element({
      buf_options = buf_options,
      win_options = win_options,
      window_mode = 'split',
      win_plot = {
        height = self.props.height or 20,
        split_direction = self.props.split_direction or 'botright',
      },
    })
  end
end

function CommitComponent:mount()
  if self._mounted then return end
  self:component_will_mount()
  self._element:mount()
  self._mounted = true
  self:component_did_mount()
end

function CommitComponent:render() end

function CommitComponent:get_layout_spec()
  return nil
end

function CommitComponent:unmount()
  if not self._mounted then return end
  if self._element then
    self._element:unmount()
    self._element = nil
  end
  Component.unmount(self)
end

function CommitComponent:get_lines()
  return self:with_element(function(el) return el:get_lines() end) or {}
end

function CommitComponent:set_lines(lines)
  self:with_element(function(el) el:set_lines(lines) end)
  return self
end

function CommitComponent:focus()
  self:with_element(function(el) el:focus() end)
  return self
end

function CommitComponent:set_cursor(cursor)
  self:with_element(function(el) el:set_cursor(cursor) end)
  return self
end

function CommitComponent:is_valid()
  return self:with_element(function() return true end) or false
end

return CommitComponent
