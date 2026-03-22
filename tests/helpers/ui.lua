local Component = require('vgit.ui.Component')
local View = require('vgit.ui.View')
local Element = require('vgit.ui.elements.Element')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

local M = {}

-- Minimal Component subclass that creates a real Element (floating window)
local TestComponent = Component({})

function TestComponent:constructor(props)
  local Base = getmetatable(TestComponent)
  local instance = Base.constructor(self, props)
  instance._log = {}
  return instance
end

function TestComponent:on_mount()
  table.insert(self._log, 'did_mount')
end

function TestComponent:get_layout_spec()
  return LayoutSpec.view(self._element, { flex = 1 })
end

M.TestComponent = TestComponent

-- Render a component via a temporary View (replacement for ComponentManager in tests)
function M.mount(config)
  local view = View()
  view:_render(config)
  return view
end

function M.cleanup_ui()
  pcall(function()
    for _, win_id in ipairs(vim.api.nvim_list_wins()) do
      local config = vim.api.nvim_win_get_config(win_id)
      if config.relative and config.relative ~= '' then pcall(vim.api.nvim_win_close, win_id, true) end
    end
  end)
  pcall(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then pcall(vim.api.nvim_buf_delete, bufnr, { force = true }) end
    end
  end)
end

function M.count_floating_windows()
  local count = 0
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win_id)
    if config.relative and config.relative ~= '' then count = count + 1 end
  end
  return count
end

return M
