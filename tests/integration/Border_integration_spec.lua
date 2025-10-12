local Layout = require('vgit.ui.Layout')
local Renderer = require('vgit.ui.Renderer')
local Component = require('vgit.ui.Component')
local Border = require('vgit.ui.components.Border')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local UnifiedDiffComponent = require('vgit.ui.components.UnifiedDiffComponent')

describe('Border Integration:', function()
  after_each(function()
    vim.cmd('silent! %bwipeout!')
  end)

  it('should render top and bottom borders with content', function()
    local mock_diff = {
      hunks = {},
      lnum_changes = {},
      stat = { added = 0, removed = 0 },
    }

    local diff_component = UnifiedDiffComponent({
      diff = mock_diff,
      filetype = 'lua',
    })

    local top_border = Border({
      text = 'test.lua (Hunk)',
    })
    local bottom_border = Border()

    local WrapperComponent = Component:extend()
    function WrapperComponent:render()
      return LayoutSpec.vertical({
        LayoutSpec.view(self.props.top_border, { height = 1 }),
        LayoutSpec.view(self.props.diff, { flex = 1 }),
        LayoutSpec.view(self.props.bottom_border, { height = 1 }),
      })
    end

    local wrapper = WrapperComponent({
      top_border = top_border,
      diff = diff_component,
      bottom_border = bottom_border,
    })

    local renderer = Renderer()
    renderer:render(Layout.popup(wrapper, {
      width = 80,
      height = 20,
    }))

    -- Wait for component_did_mount to complete
    vim.wait(100)

    -- Verify borders were mounted
    assert.is_not_nil(top_border._element)
    assert.is_not_nil(bottom_border._element)
    assert.is_true(top_border._element:is_valid())
    assert.is_true(bottom_border._element:is_valid())

    -- Verify borders have correct highlight
    local top_win = top_border._element.window
    assert.is_not_nil(top_win)
    local winhl = vim.api.nvim_win_get_option(top_win.win_id, 'winhl')
    assert.is_true(winhl:match('VGitBorder') ~= nil)

    -- Verify top border has text
    local top_lines = top_border._element.buffer:get_lines()
    assert.equals('test.lua (Hunk)', top_lines[1])

    -- Verify bottom border is empty
    local bottom_lines = bottom_border._element.buffer:get_lines()
    assert.equals('', bottom_lines[1])

    renderer:unmount()
  end)

  it('should work in lens mode', function()
    local mock_diff = {
      hunks = {},
      lnum_changes = {},
      stat = { added = 0, removed = 0 },
    }

    local diff_component = UnifiedDiffComponent({
      diff = mock_diff,
      filetype = 'lua',
    })

    local top_border = Border({ text = 'Lens Border' })
    local bottom_border = Border()

    local WrapperComponent = Component:extend()
    function WrapperComponent:render()
      return LayoutSpec.vertical({
        LayoutSpec.view(self.props.top_border, { height = 1 }),
        LayoutSpec.view(self.props.diff, { flex = 1 }),
        LayoutSpec.view(self.props.bottom_border, { height = 1 }),
      })
    end

    local wrapper = WrapperComponent({
      top_border = top_border,
      diff = diff_component,
      bottom_border = bottom_border,
    })

    local renderer = Renderer()
    renderer:render(Layout.lens(wrapper, {
      height = '20vh',
      relative = 'cursor',
    }))

    -- Verify all components mounted
    assert.is_true(top_border._element:is_valid())
    assert.is_true(bottom_border._element:is_valid())
    assert.is_not_nil(diff_component._body_element)

    renderer:unmount()
  end)

  it('should work in screen mode', function()
    local mock_diff = {
      hunks = {},
      lnum_changes = {},
      stat = { added = 0, removed = 0 },
    }

    local diff_component = UnifiedDiffComponent({
      diff = mock_diff,
      filetype = 'lua',
    })

    local top_border = Border({ text = 'Screen Border' })
    local bottom_border = Border()

    local WrapperComponent = Component:extend()
    function WrapperComponent:render()
      return LayoutSpec.vertical({
        LayoutSpec.view(self.props.top_border, { height = 1 }),
        LayoutSpec.view(self.props.diff, { flex = 1 }),
        LayoutSpec.view(self.props.bottom_border, { height = 1 }),
      })
    end

    local wrapper = WrapperComponent({
      top_border = top_border,
      diff = diff_component,
      bottom_border = bottom_border,
    })

    local renderer = Renderer()
    renderer:render(Layout.screen(wrapper))

    -- Verify all components mounted
    assert.is_true(top_border._element:is_valid())
    assert.is_true(bottom_border._element:is_valid())
    assert.is_not_nil(diff_component._body_element)

    renderer:unmount()
  end)

  it('should handle custom text highlight', function()
    local border = Border({
      text = 'Custom Text',
      text_hl = 'Keyword',
    })

    local WrapperComponent = Component:extend()
    function WrapperComponent:render()
      return LayoutSpec.vertical({
        LayoutSpec.view(self.props.border, { height = 1 }),
      })
    end

    local wrapper = WrapperComponent({ border = border })

    local renderer = Renderer()
    renderer:render(Layout.popup(wrapper, { width = 40, height = 5 }))

    -- Wait for component_did_mount to complete
    vim.wait(100)

    assert.is_true(border._element:is_valid())
    local lines = border._element.buffer:get_lines()
    assert.equals('Custom Text', lines[1])

    renderer:unmount()
  end)
end)
