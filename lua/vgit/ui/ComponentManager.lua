local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local Buffer = lazy('vgit.core.Buffer')
local Window = lazy('vgit.core.Window')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local ComponentGroup = lazy('vgit.ui.ComponentGroup')
local LayoutContext = lazy('vgit.ui.layout.LayoutContext')
local LayoutRenderer = lazy('vgit.ui.layout.LayoutRenderer')

local ComponentManager = Object:extend()

function ComponentManager:constructor(config)
  return {
    context = nil,
    root_component = nil,
    layout_renderer = nil,
    is_destroying = false,
    _tracked_elements = {},
    _lifecycle_cleanup = nil,
    _layout_spec = nil,
    ['$component_group'] = ComponentGroup(),
  }
end

function ComponentManager:parse_layout_spec(layout_spec)
  if layout_spec and layout_spec.type then
    if layout_spec.children then
      for i, child in ipairs(layout_spec.children) do
        if child.view and type(child.view.get_layout_spec) == 'function' then
          if not child.view:is_mounted() and type(child.view.mount) == 'function' then
            self.component_group:mount(child.view, self)
          end
          local child_layout_spec = child.view:get_layout_spec()
          layout_spec.children[i] = self:parse_layout_spec(child_layout_spec)
        elseif child.type and child.type == LayoutSpec.Type.VIEW and child.view then
          self._tracked_elements[#self._tracked_elements + 1] = child.view
        elseif child.type and child.type ~= LayoutSpec.Type.VIEW then
          layout_spec.children[i] = self:parse_layout_spec(child)
        end
      end
    elseif layout_spec.child then
      if layout_spec.child.view and type(layout_spec.child.view.get_layout_spec) == 'function' then
        if not layout_spec.child.view:is_mounted() and type(layout_spec.child.view.mount) == 'function' then
          self.component_group:mount(layout_spec.child.view, self)
        end
        local child_layout_spec = layout_spec.child.view:get_layout_spec()
        layout_spec.child = self:parse_layout_spec(child_layout_spec)
      elseif layout_spec.child.type and layout_spec.child.type == LayoutSpec.Type.VIEW and layout_spec.child.view then
        self._tracked_elements[#self._tracked_elements + 1] = layout_spec.child.view
      elseif layout_spec.child.type and layout_spec.child.type ~= LayoutSpec.Type.VIEW then
        layout_spec.child = self:parse_layout_spec(layout_spec.child)
      end
    end
    return layout_spec
  end

  if layout_spec and layout_spec.plot and layout_spec.plot.win_plot then
    return LayoutSpec.container(LayoutSpec.view(layout_spec, { id = 'element', flex = 1 }))
  end

  if layout_spec and layout_spec.layout then return self:parse_layout_spec(layout_spec.layout) end

  if layout_spec and type(layout_spec) == 'table' then
    return LayoutSpec.container(LayoutSpec.view(layout_spec, { id = 'pane', flex = 1 }))
  end

  error('Unable to convert UI description to LayoutSpec')
end

function ComponentManager:prepare_layout(layout_config)
  if not layout_config then error('ComponentManager:render() requires layout_config') end

  -- Support both old { component = c, mode = 'popup' } and new LayoutSpec with embedded mode
  local mode, spec

  if layout_config.component then
    -- Old style: { component = c, mode = 'popup', width = ..., height = ... }
    self.root_component = layout_config.component
    mode = layout_config.mode or 'popup'
    spec = layout_config
  elseif layout_config.type then
    -- New style: LayoutSpec with mode embedded (from LayoutSpec.screen/popup/lens)
    mode = layout_config.mode or 'popup'
    self._layout_spec = layout_config
    spec = layout_config
  else
    error('ComponentManager:render() requires a layout spec or { component = ... }')
  end

  local default_width, default_height

  if mode == 'split' then
    default_width = '100vw'
    default_height = spec.split_height or 20
  elseif mode == 'lens' then
    default_width = '100vw'
    default_height = '35vh'
  elseif mode == 'screen' then
    default_width = '100vw'
    default_height = '100vh'
  else
    default_width = '80vw'
    default_height = '60vh'
  end

  self.context = LayoutContext({
    zindex = spec.zindex or 2,
    mode = mode,
    width = spec.width or default_width,
    height = spec.height or default_height,
    relative = spec.relative or 'editor',
    position = spec.position or 'center',
  })

  if self.root_component then
    self.root_component.props = self.root_component.props or {}
    self.root_component.props.layout_config = spec
  end
end

function ComponentManager:mount_components()
  if self.root_component then self.component_group:mount(self.root_component, self) end
end

function ComponentManager:render_layout()
  local layout_spec

  if self._layout_spec then
    -- New style: spec passed directly
    layout_spec = self:parse_layout_spec(self._layout_spec)
  else
    -- Old style: get spec from root component
    layout_spec = self.root_component:get_layout_spec()
    layout_spec = self:parse_layout_spec(layout_spec)
  end

  self.layout_renderer = LayoutRenderer(self.context)
  self.layout_renderer:render(layout_spec)

  self.component_group:call_did_mount()
end

function ComponentManager:register_lifecycle_events()
  if self.context:is_floating_mode() then
    self._lifecycle_cleanup = event.disposable_on('WinLeave', function()
      event.defer(function()
        if self.is_destroying then return end

        local current_win = Window.get_current()
        for _, el in ipairs(self._tracked_elements) do
          if el:is_valid() then
            local win = el:get_window()
            if win and current_win:is_same(win) then return end
          end
        end

        self:destroy()
      end, 50)
    end)
  else
    self:on('BufWinLeave', function()
      event.await()
      self:destroy()
    end)

    self:on('QuitPre', function()
      event.await()
      self:destroy()
    end)
  end
end

function ComponentManager:render(layout_config)
  self:prepare_layout(layout_config)
  local scratch_buffer
  if self.context:is_screen_mode() then
    vim.api.nvim_command('tabnew')
    scratch_buffer = Buffer(0)
  elseif self.context:is_split_mode() then
    local height = layout_config.split_height or 20
    local direction = layout_config.split_direction or 'botright'
    vim.cmd(string.format('%s %dsplit', direction, height))
  end
  self:mount_components()
  self:render_layout()
  if scratch_buffer and scratch_buffer:is_valid() then scratch_buffer:delete({ force = true }) end
  self:register_lifecycle_events()
end

function ComponentManager:destroy()
  if self.is_destroying then return end
  self.is_destroying = true

  if self._lifecycle_cleanup then
    self._lifecycle_cleanup()
    self._lifecycle_cleanup = nil
  end

  self.component_group:unmount()
  self.context:restore_window_options()
end

function ComponentManager:on(event_name, callback)
  self.component_group:on(event_name, callback)
end

function ComponentManager:set_keymap(configs)
  self.component_group:set_keymap(configs)
end

return ComponentManager
