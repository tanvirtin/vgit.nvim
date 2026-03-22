local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local Object = lazy('vgit.core.Object')
local Buffer = lazy('vgit.core.Buffer')
local Window = lazy('vgit.core.Window')
local navigation = lazy('vgit.core.navigation')
local statusline = lazy('vgit.core.statusline_state')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local ComponentGroup = lazy('vgit.ui.ComponentGroup')
local LayoutContext = lazy('vgit.ui.layout.LayoutContext')
local LayoutCalculator = lazy('vgit.ui.layout.LayoutCalculator')
local scene_setting = lazy('vgit.settings.scene')
local hunks_setting = lazy('vgit.settings.hunks')

local View = Object:extend()

function View:constructor()
  return {
    _destroyed = false,
    _debounce_cleanups = {},
    _context = nil,
    _root_component = nil,
    _is_destroying = false,
    _tracked_elements = {},
    _lifecycle_cleanup = nil,
    _layout_spec = nil,
    _split_windows = {},
    _split_window_index = 0,
    _component_group = ComponentGroup(),
  }
end

function View:create()
  error('View:create() must be implemented by subclass')
end

function View:_resolve_layout_spec(layout_spec)
  if layout_spec and layout_spec.type then
    if
      layout_spec.type == LayoutSpec.Type.VIEW
      and layout_spec.view
      and type(layout_spec.view.get_layout_spec) ~= 'function'
    then
      self._tracked_elements[#self._tracked_elements + 1] = layout_spec.view
    end

    if layout_spec.children then
      for i, child in ipairs(layout_spec.children) do
        if child.view and type(child.view.get_layout_spec) == 'function' then
          if not child.view:is_mounted() and type(child.view.mount) == 'function' then
            self._component_group:mount(child.view, self)
          end
          local child_layout_spec = child.view:get_layout_spec()
          layout_spec.children[i] = self:_resolve_layout_spec(child_layout_spec)
        elseif child.type and child.type == LayoutSpec.Type.VIEW and child.view then
          self._tracked_elements[#self._tracked_elements + 1] = child.view
        elseif child.type and child.type ~= LayoutSpec.Type.VIEW then
          layout_spec.children[i] = self:_resolve_layout_spec(child)
        end
      end
    elseif layout_spec.child then
      if layout_spec.child.view and type(layout_spec.child.view.get_layout_spec) == 'function' then
        if not layout_spec.child.view:is_mounted() and type(layout_spec.child.view.mount) == 'function' then
          self._component_group:mount(layout_spec.child.view, self)
        end
        local child_layout_spec = layout_spec.child.view:get_layout_spec()
        layout_spec.child = self:_resolve_layout_spec(child_layout_spec)
      elseif layout_spec.child.type and layout_spec.child.type == LayoutSpec.Type.VIEW and layout_spec.child.view then
        self._tracked_elements[#self._tracked_elements + 1] = layout_spec.child.view
      elseif layout_spec.child.type and layout_spec.child.type ~= LayoutSpec.Type.VIEW then
        layout_spec.child = self:_resolve_layout_spec(layout_spec.child)
      end
    end
    return layout_spec
  end

  if layout_spec and layout_spec.plot and layout_spec.plot.win_plot then
    return LayoutSpec.container(LayoutSpec.view(layout_spec, { id = 'element', flex = 1 }))
  end

  if layout_spec and layout_spec.layout then return self:_resolve_layout_spec(layout_spec.layout) end

  if layout_spec and type(layout_spec) == 'table' then
    return LayoutSpec.container(LayoutSpec.view(layout_spec, { id = 'pane', flex = 1 }))
  end

  error('Unable to convert UI description to LayoutSpec')
end

function View:_prepare_layout(layout_config)
  if not layout_config then error('View:_render() requires layout_config') end

  local mode, spec

  if layout_config.component then
    self._root_component = layout_config.component
    mode = layout_config.mode or 'popup'
    spec = layout_config
  elseif layout_config.type then
    mode = layout_config.mode or 'popup'
    self._layout_spec = layout_config
    spec = layout_config
  else
    error('View:_render() requires a layout spec or { component = ... }')
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

  self._context = LayoutContext({
    zindex = spec.zindex or 2,
    mode = mode,
    width = spec.width or default_width,
    height = spec.height or default_height,
    relative = spec.relative or 'editor',
    position = spec.position or 'center',
  })

  if self._root_component then
    self._root_component.props = self._root_component.props or {}
    self._root_component.props.layout_config = spec
  end
end

function View:_mount_components()
  if self._root_component then self._component_group:mount(self._root_component, self) end
end

function View:_create_screen_splits(layout)
  local function create_splits(node)
    if node.spec.type == LayoutSpec.Type.VIEW then
      table.insert(self._split_windows, Window(0))
      return
    end

    local children = node.children or {}
    if #children == 0 then return end

    local split_cmd = 'vsplit'
    if node.spec.type == LayoutSpec.Type.FLEX and node.spec.direction == LayoutSpec.Direction.VERTICAL then
      split_cmd = 'split'
    end

    local child_wins = {}
    child_wins[1] = Window.get_current()
    for i = 2, #children do
      vim.cmd(split_cmd)
      child_wins[i] = Window.get_current()
    end

    for i, child in ipairs(children) do
      child_wins[i]:focus()
      create_splits(child)
    end
  end

  create_splits(layout)
end

function View:_mount_view(layout)
  local spec = layout.spec
  local view = spec.view
  local bounds = layout.bounds

  if not view then return end

  if (self._context:is_screen_mode() or self._context:is_split_mode()) and #self._split_windows > 0 then
    self._split_window_index = self._split_window_index + 1
    if self._split_window_index <= #self._split_windows then
      local target_window = self._split_windows[self._split_window_index]
      if target_window and target_window:is_valid() then target_window:focus() end
    end
  end

  view:set_window_mode(self._context.mode)

  local win_plot = bounds:to_win_plot({
    relative = 'editor',
    zindex = spec.zindex or 2,
    focus = spec.focus or false,
  })

  view:apply_layout_win_plot(win_plot)

  if view.mount then view:mount() end

  if (self._context:is_screen_mode() or self._context:is_split_mode()) and view.ensure_window_options then
    event.await()
    view:ensure_window_options()
  end

  if spec.focus and type(view.focus) == 'function' then view:focus() end
end

function View:_mount_layout(layout)
  local spec_type = layout.spec.type

  if spec_type == LayoutSpec.Type.VIEW then
    self:_mount_view(layout)
  else
    for _, child_layout in ipairs(layout.children) do
      self:_mount_layout(child_layout)
    end
  end
end

function View:_render_layout()
  local layout_spec

  if self._layout_spec then
    layout_spec = self:_resolve_layout_spec(self._layout_spec)
  else
    layout_spec = self._root_component:get_layout_spec()
    layout_spec = self:_resolve_layout_spec(layout_spec)
  end

  local calculator = LayoutCalculator()
  local parent_bounds = self._context:create_parent_bounds()
  local layout = calculator:calculate(layout_spec, parent_bounds, self._context)

  if self._context:is_screen_mode() or self._context:is_split_mode() then self:_create_screen_splits(layout) end

  self:_mount_layout(layout)
  self._component_group:call_did_mount()
end

function View:_register_lifecycle_events()
  if self._context:is_floating_mode() and #self._tracked_elements <= 1 then
    self._lifecycle_cleanup = event.disposable_on('WinLeave', function()
      event.defer(function()
        if self._is_destroying then return end

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
  elseif self._context:is_floating_mode() then
    self._lifecycle_cleanup = event.disposable_on('WinLeave', function()
      event.defer(function()
        if self._is_destroying then return end

        local current_win = Window.get_current()

        for _, el in ipairs(self._tracked_elements) do
          if el:is_valid() then
            local win = el:get_window()
            if win and current_win:is_same(win) then return end
          end
        end

        for _, component in ipairs(self._component_group:get_mounted_components()) do
          if component.with_element then
            local still_focused = component:with_element(function(el)
              local win = el:get_window()
              return win and current_win:is_same(win)
            end)
            if still_focused then return end
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

function View:_render(layout_config)
  if self._context then error('View:_render() called twice on the same View instance') end
  self:_prepare_layout(layout_config)
  local scratch_buffer
  if self._context:is_screen_mode() then
    vim.api.nvim_command('tabnew')
    scratch_buffer = Buffer(0)
  elseif self._context:is_split_mode() then
    local height = layout_config.split_height or 20
    local direction = layout_config.split_direction or 'botright'
    vim.cmd(string.format('%s %dsplit', direction, height))
  end
  self:_mount_components()
  self:_render_layout()
  if scratch_buffer and scratch_buffer:is_valid() then scratch_buffer:delete({ force = true }) end
  self:_register_lifecycle_events()
end

function View:destroy()
  if self._destroyed then return end
  if self._is_destroying then return end
  self._is_destroying = true
  self._destroyed = true

  for _, cleanup in ipairs(self._debounce_cleanups) do
    cleanup()
  end
  self._debounce_cleanups = {}

  if self._lifecycle_cleanup then
    self._lifecycle_cleanup()
    self._lifecycle_cleanup = nil
  end

  self._component_group:unmount()

  if self._context then self._context:restore_window_options() end
end

function View:is_destroyed()
  return self._destroyed
end

function View:on(event_name, callback)
  self._component_group:on(event_name, callback)
end

function View:set_keymap(configs)
  self._component_group:set_keymap(configs)
end

function View:_setup_quit_keymap()
  local scene_keymaps = scene_setting:get('keymaps')
  if not scene_keymaps or not scene_keymaps.quit then return end
  local quit_key = keymap.get_key(scene_keymaps.quit)
  if not quit_key then return end
  self:set_keymap({ {
    mode = 'n',
    key = quit_key,
    handler = function()
      self:destroy()
    end,
  } })
end

function View:_setup_hunk_navigation_keymaps()
  local hunks_keymaps = hunks_setting:get('keymaps')
  if not hunks_keymaps then return end
  local down_key = keymap.get_key(hunks_keymaps.down)
  if down_key then
    self:set_keymap({ { mode = 'n', key = down_key, handler = event.async(function()
      self:hunk_down()
    end) } })
  end
  local up_key = keymap.get_key(hunks_keymaps.up)
  if up_key then
    self:set_keymap({ { mode = 'n', key = up_key, handler = event.async(function()
      self:hunk_up()
    end) } })
  end
end

function View:get_context()
  return self._context
end

function View:on_git_change() end

-- Keymap registration helpers (Command Pattern)

function View:_register_keymap(component, mode, key, handler)
  local fn, cleanup = event.debounce_async(handler, self.DEBOUNCE_MS or 100)
  table.insert(self._debounce_cleanups, cleanup)
  component:set_keymap({ mode = mode, key = key }, fn)
end

function View:_make_debounced(fn)
  local debounced, cleanup = event.debounce_async(fn, self.DEBOUNCE_MS or 100)
  table.insert(self._debounce_cleanups, cleanup)
  return debounced
end

function View:_confirm(prompt)
  local decision = console.input(prompt)
  if not decision then return false end
  decision = decision:lower()
  return decision == 'yes' or decision == 'y'
end

-- Hunk navigation template methods (override in subclasses)

function View:get_navigatable_component()
  if self._layout_type == 'split' then return self._current_component end
  if self._patch_component then return self._patch_component end
  return nil
end

function View:get_hunk_alignment()
  return 'center'
end
function View:get_hunk_alignment_offset()
  return 0
end

function View:_get_all_diff_components()
  if self._layout_type == 'split' then
    local components = {}
    if self._previous_component then components[#components + 1] = self._previous_component end
    if self._current_component then components[#components + 1] = self._current_component end
    return components
  end
  if self._patch_component then return { self._patch_component } end
  return {}
end

function View:_set_keymap_all_components(mode, key, handler)
  for _, component in ipairs(self:_get_all_diff_components()) do
    if component and component:is_valid() then component:set_keymap({ mode = mode, key = key }, handler) end
  end
end

function View:_set_hunk_entries(hunk_entries)
  if self._layout_type == 'split' then
    if self._previous_component and self._previous_component:is_valid() then
      local previous_entries = {}
      for _, entry in ipairs(hunk_entries) do
        previous_entries[#previous_entries + 1] = vim.tbl_extend('force', entry, { buftype = 'previous' })
      end
      self._previous_component:set_props({ hunk_entries = previous_entries })
    end
    if self._current_component and self._current_component:is_valid() then
      local current_entries = {}
      for _, entry in ipairs(hunk_entries) do
        current_entries[#current_entries + 1] = vim.tbl_extend('force', entry, { buftype = 'current' })
      end
      self._current_component:set_props({ hunk_entries = current_entries })
    end
  else
    if self._patch_component and self._patch_component:is_valid() then
      self._patch_component:set_props({ hunk_entries = hunk_entries })
    end
  end
end

function View:get_current_mark_index()
  local component = self:get_navigatable_component()
  if not component then return nil, 0 end
  return navigation.get_mark_index(component:get_marks(), component:get_lnum())
end

function View:hunk_up()
  local component = self:get_navigatable_component()
  if not component or not component:is_valid() then return end
  component:hunk_up(self:get_hunk_alignment(), self:get_hunk_alignment_offset())
  local index, count = self:get_current_mark_index()
  if index then statusline.set_hunk({ index = index, count = count }) end
end

function View:hunk_down()
  local component = self:get_navigatable_component()
  if not component or not component:is_valid() then return end
  component:hunk_down(self:get_hunk_alignment(), self:get_hunk_alignment_offset())
  local index, count = self:get_current_mark_index()
  if index then statusline.set_hunk({ index = index, count = count }) end
end

-- Diff component factory method

function View:_create_diff_component(opts, layout_type)
  local DiffComponent = require('vgit.ui.components.DiffComponent')
  local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')

  opts = opts or {}
  local props = {
    diff = opts.diff,
    filename = opts.filename,
    filetype = opts.filetype or 'text',
  }

  if layout_type == 'split' then return SplitDiffComponent(props) end
  return DiffComponent(props)
end

return View
