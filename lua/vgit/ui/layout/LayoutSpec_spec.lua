local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

local eq = assert.are.same

describe('LayoutSpec', function()
  local mock_view

  before_each(function()
    mock_view = { mount = function() end }
  end)

  describe('container', function()
    it('should create container spec', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.container(child)

      eq(LayoutSpec.Type.CONTAINER, spec.type)
      eq(child, spec.child)
    end)
  end)

  describe('horizontal', function()
    it('should create horizontal flex spec', function()
      local children = {
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 2 }),
      }
      local spec = LayoutSpec.horizontal(children)

      eq(LayoutSpec.Type.FLEX, spec.type)
      eq(LayoutSpec.Direction.HORIZONTAL, spec.direction)
      eq(2, #spec.children)
    end)

    it('should accept gap option', function()
      local spec = LayoutSpec.horizontal({}, { gap = 5 })
      eq(5, spec.gap)
    end)

    it('should handle nil children', function()
      local spec = LayoutSpec.horizontal()
      eq(LayoutSpec.Type.FLEX, spec.type)
      eq(0, #spec.children)
    end)
  end)

  describe('vertical', function()
    it('should create vertical flex spec', function()
      local children = {
        LayoutSpec.view(mock_view, { flex = 1 }),
      }
      local spec = LayoutSpec.vertical(children)

      eq(LayoutSpec.Type.FLEX, spec.type)
      eq(LayoutSpec.Direction.VERTICAL, spec.direction)
      eq(1, #spec.children)
    end)

    it('should accept align and justify options', function()
      local spec = LayoutSpec.vertical({}, {
        align = LayoutSpec.Align.CENTER,
        justify = LayoutSpec.Justify.SPACE_BETWEEN,
      })

      eq(LayoutSpec.Align.CENTER, spec.align)
      eq(LayoutSpec.Justify.SPACE_BETWEEN, spec.justify)
    end)
  end)

  describe('row', function()
    it('should create horizontal spec with default align and justify', function()
      local spec = LayoutSpec.row({})

      eq(LayoutSpec.Type.FLEX, spec.type)
      eq(LayoutSpec.Direction.HORIZONTAL, spec.direction)
      eq(LayoutSpec.Align.CENTER, spec.align)
      eq(LayoutSpec.Justify.START, spec.justify)
      eq(0, spec.gap)
    end)

    it('should accept custom gap', function()
      local spec = LayoutSpec.row({}, { gap = 10 })
      eq(10, spec.gap)
    end)
  end)

  describe('flex', function()
    it('should create flex spec with all options', function()
      local spec = LayoutSpec.flex({
        direction = 'vertical',
        children = {},
        gap = 5,
        flex = 2,
        width = 100,
        height = 50,
        min_width = 10,
        max_width = 200,
        min_height = 10,
        max_height = 100,
      })

      eq(LayoutSpec.Type.FLEX, spec.type)
      eq('vertical', spec.direction)
      eq(5, spec.gap)
      eq(2, spec.flex)
      eq(100, spec.width)
      eq(50, spec.height)
      eq(10, spec.min_width)
      eq(200, spec.max_width)
    end)

    it('should default direction to horizontal', function()
      local spec = LayoutSpec.flex({})
      eq(LayoutSpec.Direction.HORIZONTAL, spec.direction)
    end)
  end)

  describe('absolute', function()
    it('should create absolute spec with all options', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.absolute(child, {
        anchor = 'top-left',
        offset = { row = 5, col = 10 },
        width = 100,
        height = 50,
        zindex = 3,
      })

      eq(LayoutSpec.Type.ABSOLUTE, spec.type)
      eq(child, spec.child)
      eq('top-left', spec.anchor)
      eq(100, spec.width)
      eq(50, spec.height)
      eq(3, spec.zindex)
      eq(5, spec.offset.row)
      eq(10, spec.offset.col)
    end)

    it('should default anchor to center', function()
      local spec = LayoutSpec.absolute(nil, {})
      eq(LayoutSpec.Anchor.CENTER, spec.anchor)
    end)
  end)

  describe('view', function()
    it('should create view spec', function()
      local spec = LayoutSpec.view(mock_view, {
        id = 'test',
        flex = 2,
        focus = true,
      })

      eq(LayoutSpec.Type.VIEW, spec.type)
      eq(mock_view, spec.view)
      eq('test', spec.id)
      eq(2, spec.flex)
      assert.is_true(spec.focus)
    end)

    it('should default flex to 1', function()
      local spec = LayoutSpec.view(mock_view, {})
      eq(1, spec.flex)
    end)

    it('should handle width/height constraints', function()
      local spec = LayoutSpec.view(mock_view, {
        width = 100,
        height = 50,
        min_width = 10,
        max_width = 200,
      })

      eq(100, spec.width)
      eq(50, spec.height)
      eq(10, spec.min_width)
      eq(200, spec.max_width)
    end)
  end)

  describe('screen', function()
    it('should create absolute fullscreen spec', function()
      local spec = LayoutSpec.screen({
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      eq(LayoutSpec.Type.ABSOLUTE, spec.type)
      eq('100vw', spec.width)
      eq('100vh', spec.height)
      eq(LayoutSpec.Anchor.CENTER, spec.anchor)
      eq(1, spec.zindex)

      -- Child should be vertical flex
      eq(LayoutSpec.Type.FLEX, spec.child.type)
      eq(LayoutSpec.Direction.VERTICAL, spec.child.direction)
    end)

    it('should accept custom zindex', function()
      local spec = LayoutSpec.screen({}, { zindex = 5 })
      eq(5, spec.zindex)
    end)
  end)

  describe('popup', function()
    it('should create centered popup spec with defaults', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.popup(child)

      eq(LayoutSpec.Type.ABSOLUTE, spec.type)
      eq('80vw', spec.width)
      eq('60vh', spec.height)
      eq(LayoutSpec.Anchor.CENTER, spec.anchor)
      eq(2, spec.zindex)
    end)

    it('should accept custom dimensions', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.popup(child, {
        width = '50vw',
        height = '40vh',
        zindex = 10,
      })

      eq('50vw', spec.width)
      eq('40vh', spec.height)
      eq(10, spec.zindex)
    end)
  end)

  describe('lens', function()
    it('should create lens spec with defaults', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.lens(child)

      eq(LayoutSpec.Type.ABSOLUTE, spec.type)
      eq('100vw', spec.width)
      eq('35vh', spec.height)
      eq(LayoutSpec.Anchor.CENTER, spec.anchor)
      eq(2, spec.zindex)
    end)

    it('should accept custom dimensions', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.lens(child, {
        width = '80vw',
        height = '50vh',
      })

      eq('80vw', spec.width)
      eq('50vh', spec.height)
    end)
  end)

  describe('center', function()
    it('should create centered absolute spec', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.center(child, { width = 100, height = 50 })

      eq(LayoutSpec.Type.ABSOLUTE, spec.type)
      eq(LayoutSpec.Anchor.CENTER, spec.anchor)
      eq(100, spec.width)
      eq(50, spec.height)
    end)
  end)

  describe('full_width', function()
    it('should create full-width spec', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.full_width(child, { height = 50 })

      eq(LayoutSpec.Type.ABSOLUTE, spec.type)
      eq('100vw', spec.width)
      eq(50, spec.height)
      eq(LayoutSpec.Anchor.TOP_LEFT, spec.anchor)
    end)
  end)

  describe('full_height', function()
    it('should create full-height spec', function()
      local child = LayoutSpec.view(mock_view)
      local spec = LayoutSpec.full_height(child, { width = 100 })

      eq(LayoutSpec.Type.ABSOLUTE, spec.type)
      eq(100, spec.width)
      eq('100vh', spec.height)
      eq(LayoutSpec.Anchor.TOP_LEFT, spec.anchor)
    end)
  end)
end)
