local Layout = require('vgit.ui.Layout')

local eq = assert.are.same

describe('Layout:', function()
  local component

  before_each(function()
    component = { type = 'test_component' }
  end)

  describe('screen', function()
    it('should create screen layout with defaults', function()
      local layout = Layout.screen(component)

      eq('screen', layout.mode)
      eq(component, layout.component)
      assert.is_nil(layout.width)
      assert.is_nil(layout.height)
    end)

    it('should accept width and height options', function()
      local layout = Layout.screen(component, {
        width = 100,
        height = 50,
      })

      eq('screen', layout.mode)
      eq(100, layout.width)
      eq(50, layout.height)
    end)

    it('should handle nil options', function()
      local layout = Layout.screen(component, nil)

      eq('screen', layout.mode)
      eq(component, layout.component)
    end)
  end)

  describe('lens', function()
    it('should create lens layout with defaults', function()
      local layout = Layout.lens(component)

      eq('lens', layout.mode)
      eq(component, layout.component)
      eq('cursor', layout.position)
      eq('40vh', layout.height)
      eq(2, layout.zindex)
      assert.is_nil(layout.width)
    end)

    it('should accept custom options', function()
      local layout = Layout.lens(component, {
        position = 'top',
        width = '80vw',
        height = '30vh',
        zindex = 5,
      })

      eq('lens', layout.mode)
      eq('top', layout.position)
      eq('80vw', layout.width)
      eq('30vh', layout.height)
      eq(5, layout.zindex)
    end)

    it('should handle nil options', function()
      local layout = Layout.lens(component, nil)

      eq('lens', layout.mode)
      eq('cursor', layout.position)
      eq('40vh', layout.height)
    end)
  end)

  describe('popup', function()
    it('should create popup layout with defaults', function()
      local layout = Layout.popup(component)

      eq('popup', layout.mode)
      eq(component, layout.component)
      eq('center', layout.position)
      eq(80, layout.width)
      eq(20, layout.height)
      eq('rounded', layout.border)
      eq(10, layout.zindex)
      assert.is_nil(layout.title)
    end)

    it('should accept custom options', function()
      local layout = Layout.popup(component, {
        position = 'top-left',
        width = 100,
        height = 50,
        border = 'single',
        title = 'Test Popup',
        zindex = 15,
      })

      eq('popup', layout.mode)
      eq('top-left', layout.position)
      eq(100, layout.width)
      eq(50, layout.height)
      eq('single', layout.border)
      eq('Test Popup', layout.title)
      eq(15, layout.zindex)
    end)

    it('should handle nil options', function()
      local layout = Layout.popup(component, nil)

      eq('popup', layout.mode)
      eq('center', layout.position)
      eq(80, layout.width)
      eq(20, layout.height)
    end)
  end)

  describe('integration', function()
    it('should create different layout types for same component', function()
      local screen_layout = Layout.screen(component)
      local lens_layout = Layout.lens(component)
      local popup_layout = Layout.popup(component)

      eq('screen', screen_layout.mode)
      eq('lens', lens_layout.mode)
      eq('popup', popup_layout.mode)

      -- All should reference same component
      eq(component, screen_layout.component)
      eq(component, lens_layout.component)
      eq(component, popup_layout.component)
    end)

    it('should support method chaining pattern', function()
      -- While Layout helpers don't chain, they work well with renderer
      local screen = Layout.screen(component, { width = 100 })
      local lens = Layout.lens(component, { height = '50vh' })
      local popup = Layout.popup(component, { title = 'Test' })

      assert.is_not_nil(screen)
      assert.is_not_nil(lens)
      assert.is_not_nil(popup)
    end)
  end)
end)
