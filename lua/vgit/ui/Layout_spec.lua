local Layout = require('vgit.ui.Layout')

describe('V2 Layout helpers', function()
  local component

  before_each(function()
    component = { type = 'test_component' }
  end)

  describe('screen', function()
    it('should create screen layout with defaults', function()
      local layout = Layout.screen(component)

      assert.are.same('screen', layout.mode)
      assert.are.same(component, layout.component)
      assert.is_nil(layout.width)
      assert.is_nil(layout.height)
    end)

    it('should accept width and height options', function()
      local layout = Layout.screen(component, {
        width = 100,
        height = 50,
      })

      assert.are.same('screen', layout.mode)
      assert.are.same(100, layout.width)
      assert.are.same(50, layout.height)
    end)

    it('should handle nil options', function()
      local layout = Layout.screen(component, nil)

      assert.are.same('screen', layout.mode)
      assert.are.same(component, layout.component)
    end)
  end)

  describe('lens', function()
    it('should create lens layout with defaults', function()
      local layout = Layout.lens(component)

      assert.are.same('lens', layout.mode)
      assert.are.same(component, layout.component)
      assert.are.same('cursor', layout.position)
      assert.are.same('40vh', layout.height)
      assert.are.same(2, layout.zindex)
      assert.is_nil(layout.width)
    end)

    it('should accept custom options', function()
      local layout = Layout.lens(component, {
        position = 'top',
        width = '80vw',
        height = '30vh',
        zindex = 5,
      })

      assert.are.same('lens', layout.mode)
      assert.are.same('top', layout.position)
      assert.are.same('80vw', layout.width)
      assert.are.same('30vh', layout.height)
      assert.are.same(5, layout.zindex)
    end)

    it('should handle nil options', function()
      local layout = Layout.lens(component, nil)

      assert.are.same('lens', layout.mode)
      assert.are.same('cursor', layout.position)
      assert.are.same('40vh', layout.height)
    end)
  end)

  describe('popup', function()
    it('should create popup layout with defaults', function()
      local layout = Layout.popup(component)

      assert.are.same('popup', layout.mode)
      assert.are.same(component, layout.component)
      assert.are.same('center', layout.position)
      assert.are.same(80, layout.width)
      assert.are.same(20, layout.height)
      assert.are.same('rounded', layout.border)
      assert.are.same(10, layout.zindex)
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

      assert.are.same('popup', layout.mode)
      assert.are.same('top-left', layout.position)
      assert.are.same(100, layout.width)
      assert.are.same(50, layout.height)
      assert.are.same('single', layout.border)
      assert.are.same('Test Popup', layout.title)
      assert.are.same(15, layout.zindex)
    end)

    it('should handle nil options', function()
      local layout = Layout.popup(component, nil)

      assert.are.same('popup', layout.mode)
      assert.are.same('center', layout.position)
      assert.are.same(80, layout.width)
      assert.are.same(20, layout.height)
    end)
  end)

  describe('integration', function()
    it('should create different layout types for same component', function()
      local screen_layout = Layout.screen(component)
      local lens_layout = Layout.lens(component)
      local popup_layout = Layout.popup(component)

      assert.are.same('screen', screen_layout.mode)
      assert.are.same('lens', lens_layout.mode)
      assert.are.same('popup', popup_layout.mode)

      -- All should reference same component
      assert.are.same(component, screen_layout.component)
      assert.are.same(component, lens_layout.component)
      assert.are.same(component, popup_layout.component)
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
