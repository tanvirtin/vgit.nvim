local Renderer = require('vgit.ui.Renderer')
local Layout = require('vgit.ui.Layout')
local DiffHeader = require('vgit.ui.components.DiffHeader')
local DiffWithHeader = require('vgit.ui.components.DiffWithHeader')
local UnifiedDiffComponent = require('vgit.ui.components.UnifiedDiffComponent')
local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')

describe('DiffWithHeader Integration', function()
  local function create_test_diff()
    return {
      lines = {
        { '- old line 1', 'remove' },
        { '+ new line 1', 'add' },
        { '  context line', 'void' },
      },
      hunks = {
        {
          top = 1,
          bot = 3,
          type = 'remove',
        },
      },
    }
  end

  after_each(function()
    -- Clean up any created buffers/windows
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and not vim.api.nvim_buf_get_name(buf):match('^/') then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end)

  describe('UnifiedDiff with Header', function()
    it('should render header + unified diff in popup mode', function()
      local diff_data = create_test_diff()

      local diff_component = UnifiedDiffComponent({
        data = diff_data,
        filetype = 'lua',
      })

      local header = DiffHeader({
        filename = 'test.lua',
        status = '(Modified)',
      })

      local container = DiffWithHeader({
        header = header,
        diff_component = diff_component,
      })

      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(container, { width = 80, height = 30 }))
      end)

      -- Verify components are mounted
      assert.is_true(container.mounted)
      assert.is_true(header.mounted)
      assert.is_true(diff_component.mounted)

      renderer:destroy()
    end)

    it('should render header + unified diff in lens mode', function()
      local diff_data = create_test_diff()

      local diff_component = UnifiedDiffComponent({
        data = diff_data,
        filetype = 'lua',
      })

      local header = DiffHeader({
        filename = 'test.lua',
        status = '(Hunk)',
      })

      local container = DiffWithHeader({
        header = header,
        diff_component = diff_component,
      })

      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.lens(container, { height = '35vh' }))
      end)

      assert.is_true(container.mounted)
      renderer:destroy()
    end)

    it('should render header + unified diff in screen mode', function()
      local diff_data = create_test_diff()

      local diff_component = UnifiedDiffComponent({
        data = diff_data,
        filetype = 'lua',
      })

      local header = DiffHeader({
        filename = 'test.lua',
        status = '(Staged)',
      })

      local container = DiffWithHeader({
        header = header,
        diff_component = diff_component,
      })

      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.screen(container))
      end)

      assert.is_true(container.mounted)
      renderer:destroy()
    end)
  end)

  describe('SplitDiff with Header', function()
    it('should render header + split diff in popup mode', function()
      local diff_data = create_test_diff()

      local diff_component = SplitDiffComponent({
        data = diff_data,
        filetype = 'lua',
      })

      local header = DiffHeader({
        filename = 'test.lua',
        status = '(Modified)',
      })

      local container = DiffWithHeader({
        header = header,
        diff_component = diff_component,
      })

      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(container, { width = 120, height = 40 }))
      end)

      assert.is_true(container.mounted)
      assert.is_true(header.mounted)
      assert.is_true(diff_component.mounted)

      renderer:destroy()
    end)

    it('should render header + split diff in screen mode', function()
      local diff_data = create_test_diff()

      local diff_component = SplitDiffComponent({
        data = diff_data,
        filetype = 'lua',
      })

      local header = DiffHeader({
        filename = 'test.lua',
        status = '(Unstaged)',
      })

      local container = DiffWithHeader({
        header = header,
        diff_component = diff_component,
      })

      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.screen(container))
      end)

      assert.is_true(container.mounted)
      renderer:destroy()
    end)
  end)

  describe('DiffHeader Component', function()
    it('should render filename and status', function()
      local header = DiffHeader({
        filename = 'my_file.lua',
        status = '(Test Status)',
      })

      -- Header should work standalone
      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(header, { width = 80, height = 1 }))
      end)

      assert.is_true(header.mounted)

      -- Verify header element exists
      assert.is_not_nil(header._element)
      assert.is_true(header._element:is_valid())

      renderer:destroy()
    end)

    it('should handle empty filename and status gracefully', function()
      local header = DiffHeader({})

      local renderer = Renderer()

      assert.has_no.errors(function()
        renderer:render(Layout.popup(header, { width = 80, height = 1 }))
      end)

      assert.is_true(header.mounted)
      renderer:destroy()
    end)
  end)

  describe('Error Handling', function()
    it('should error when DiffWithHeader missing header prop', function()
      local diff_component = UnifiedDiffComponent({ data = create_test_diff() })
      local container = DiffWithHeader({
        diff_component = diff_component,
      })

      assert.has_error(function()
        container:render()
      end)
    end)

    it('should error when DiffWithHeader missing diff_component prop', function()
      local header = DiffHeader({ filename = 'test.lua' })
      local container = DiffWithHeader({
        header = header,
      })

      assert.has_error(function()
        container:render()
      end)
    end)
  end)
end)
