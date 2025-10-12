local Layout = require('vgit.ui.Layout')
local Renderer = require('vgit.ui.Renderer')
local Component = require('vgit.ui.Component')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

describe('Layout & Renderer Integration', function()
  local Element = require('vgit.ui.elements.Element')
  local TestComponent
  local HeaderComponent
  local ContentComponent

  before_each(function()
    -- Simple test component that creates an Element
    TestComponent = Component:extend()
    function TestComponent:constructor(props)
      return Component.constructor(self, props)
    end

    function TestComponent:render()
      local element = Element({
        buf_options = { modifiable = false, buflisted = false },
        win_options = {},
      })
      return LayoutSpec.view(element, { flex = 1 })
    end

    function TestComponent:component_did_mount()
      -- Element will have buffer after mount
    end

    -- Header component
    HeaderComponent = Component:extend()
    function HeaderComponent:constructor(props)
      return Component.constructor(self, props)
    end

    function HeaderComponent:render()
      local element = Element({
        buf_options = { modifiable = false, buflisted = false },
        win_options = {},
      })
      return LayoutSpec.view(element, { height = 1 })
    end

    function HeaderComponent:component_did_mount()
      -- Element will have buffer after mount
    end

    -- Content component
    ContentComponent = Component:extend()
    function ContentComponent:constructor(props)
      return Component.constructor(self, props)
    end

    function ContentComponent:render()
      local element = Element({
        buf_options = { modifiable = false, buflisted = false },
        win_options = {},
      })
      return LayoutSpec.view(element, { flex = 1 })
    end

    function ContentComponent:component_did_mount()
      -- Element will have buffer after mount
    end
  end)

  after_each(function()
    -- Clean up any created buffers/windows
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and not vim.api.nvim_buf_get_name(buf):match('^/') then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end)

  describe('Basic Component Rendering', function()
    it('should render a simple component using LayoutSpec', function()
      local component = TestComponent({ text = 'Hello' })
      local renderer = Renderer()

      -- Should not error
      assert.has_no.errors(function()
        renderer:render(Layout.popup(component, { width = 80, height = 20 }))
      end)

      -- Component should be mounted
      assert.is_true(component.mounted)

      renderer:destroy()
    end)

    it('should render in screen mode', function()
      local component = TestComponent({ text = 'Screen' })
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.screen(component))
      end)

      assert.is_true(component.mounted)
      renderer:destroy()
    end)

    it('should render in lens mode', function()
      local component = TestComponent({ text = 'Lens' })
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.lens(component, { height = '20vh' }))
      end)

      assert.is_true(component.mounted)
      renderer:destroy()
    end)
  end)

  describe('Composite Components with Layout', function()
    it('should render a component that returns vertical layout', function()
      -- Component that composes header + content using vertical layout
      local CompositeComponent = Component:extend()
      function CompositeComponent:constructor(props)
        return Component.constructor(self, props)
      end

      function CompositeComponent:render()
        local header = HeaderComponent({ text = 'My Header' })
        local content = ContentComponent({ text = 'My Content' })

        -- Return a vertical layout
        return LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 1 }),
          LayoutSpec.view(content, { flex = 1 }),
        })
      end

      local component = CompositeComponent()
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(component, { width = 80, height = 20 }))
      end)

      renderer:destroy()
    end)

    it('should render a component that returns horizontal layout', function()
      local CompositeComponent = Component:extend()
      function CompositeComponent:constructor(props)
        return Component.constructor(self, props)
      end

      function CompositeComponent:render()
        local left = ContentComponent({ text = 'Left' })
        local right = ContentComponent({ text = 'Right' })

        return LayoutSpec.horizontal({
          LayoutSpec.view(left, { flex = 1 }),
          LayoutSpec.view(right, { flex = 1 }),
        })
      end

      local component = CompositeComponent()
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(component, { width = 100, height = 30 }))
      end)

      renderer:destroy()
    end)
  end)

  describe('Nested Layouts', function()
    it('should handle deeply nested vertical layouts', function()
      local NestedComponent = Component:extend()
      function NestedComponent:constructor(props)
        return Component.constructor(self, props)
      end

      function NestedComponent:render()
        local h1 = HeaderComponent({ text = 'H1' })
        local h2 = HeaderComponent({ text = 'H2' })
        local content = ContentComponent({ text = 'Content' })

        return LayoutSpec.vertical({
          LayoutSpec.view(h1, { height = 1 }),
          LayoutSpec.view(h2, { height = 1 }),
          LayoutSpec.view(content, { flex = 1 }),
        })
      end

      local component = NestedComponent()
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(component, { width = 80, height = 30 }))
      end)

      renderer:destroy()
    end)

    it('should handle vertical inside horizontal layout', function()
      local ComplexComponent = Component:extend()
      function ComplexComponent:constructor(props)
        return Component.constructor(self, props)
      end

      function ComplexComponent:render()
        local LeftPanel = Component:extend()
        function LeftPanel:render()
          return LayoutSpec.vertical({
            LayoutSpec.view(HeaderComponent({ text = 'Left Header' }), { height = 1 }),
            LayoutSpec.view(ContentComponent({ text = 'Left Content' }), { flex = 1 }),
          })
        end

        local RightPanel = Component:extend()
        function RightPanel:render()
          return LayoutSpec.vertical({
            LayoutSpec.view(HeaderComponent({ text = 'Right Header' }), { height = 1 }),
            LayoutSpec.view(ContentComponent({ text = 'Right Content' }), { flex = 1 }),
          })
        end

        return LayoutSpec.horizontal({
          LayoutSpec.view(LeftPanel(), { flex = 1 }),
          LayoutSpec.view(RightPanel(), { flex = 1 }),
        })
      end

      local component = ComplexComponent()
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(component, { width = 120, height = 40 }))
      end)

      renderer:destroy()
    end)
  end)

  describe('Real-World Use Cases', function()
    it('should render DiffComponent with header using vertical layout', function()
      -- Simulate a diff component with header
      local DiffWithHeader = Component:extend()
      function DiffWithHeader:constructor(props)
        return Component.constructor(self, props)
      end

      function DiffWithHeader:render()
        local header = HeaderComponent({ text = self.props.filename or 'unknown.txt' })
        local diff = ContentComponent({ text = 'Diff content here' })

        return LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 1 }),
          LayoutSpec.view(diff, { flex = 1 }),
        })
      end

      local component = DiffWithHeader({ filename = 'test.lua' })
      local renderer = Renderer()

      -- Lens mode
      assert.has_no.errors(function()
        renderer:render(Layout.lens(component, { height = '35vh' }))
      end)
      renderer:destroy()

      -- Screen mode
      local renderer2 = Renderer()
      local component2 = DiffWithHeader({ filename = 'test.lua' })
      assert.has_no.errors(function()
        renderer2:render(Layout.screen(component2))
      end)
      renderer2:destroy()
    end)

    it('should render SplitDiff with shared header using vertical + horizontal', function()
      local SplitDiffWithHeader = Component:extend()
      function SplitDiffWithHeader:constructor(props)
        return Component.constructor(self, props)
      end

      function SplitDiffWithHeader:render()
        local header = HeaderComponent({ text = self.props.filename or 'unknown.txt' })
        local prev = ContentComponent({ text = 'Previous version' })
        local curr = ContentComponent({ text = 'Current version' })

        return LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 1 }),
          LayoutSpec.horizontal({
            LayoutSpec.view(prev, { flex = 1 }),
            LayoutSpec.view(curr, { flex = 1 }),
          }),
        })
      end

      local component = SplitDiffWithHeader({ filename = 'test.lua' })
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(component, { width = 140, height = 50 }))
      end)

      renderer:destroy()
    end)
  end)

  describe('Component Lifecycle with Layouts', function()
    it('should call component_did_mount for all nested components', function()
      local mount_order = {}

      local TrackedHeader = Component:extend()
      function TrackedHeader:constructor(props)
        return Component.constructor(self, props)
      end

      function TrackedHeader:render()
        return LayoutSpec.view(self, { height = 1 })
      end

      function TrackedHeader:component_did_mount()
        table.insert(mount_order, 'header')
      end

      local TrackedContent = Component:extend()
      function TrackedContent:constructor(props)
        return Component.constructor(self, props)
      end

      function TrackedContent:render()
        return LayoutSpec.view(self, { flex = 1 })
      end

      function TrackedContent:component_did_mount()
        table.insert(mount_order, 'content')
      end

      local Container = Component:extend()
      function Container:render()
        return LayoutSpec.vertical({
          LayoutSpec.view(TrackedHeader(), { height = 1 }),
          LayoutSpec.view(TrackedContent(), { flex = 1 }),
        })
      end

      local component = Container()
      local renderer = Renderer()

      renderer:render(Layout.popup(component, { width = 80, height = 20 }))

      -- Both components should have mounted
      vim.wait(100) -- Wait for async mount
      assert.is_true(#mount_order >= 2)

      renderer:destroy()
    end)
  end)
end)
