local Component = require('vgit.ui.Component')
local Element = require('vgit.ui.elements.Element')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

local M = {}

-- Minimal Component subclass that creates a real Element (floating window)
local TestComponent = Component:extend()

function TestComponent:constructor(props)
  local instance = TestComponent.super.constructor(self, props)
  instance._log = {}
  instance._element = nil
  return instance
end

function TestComponent:component_will_mount()
  table.insert(self._log, 'will_mount')
  self._element = Element({
    win_plot = {
      relative = 'editor',
      width = 20,
      height = 5,
      row = 0,
      col = 0,
      style = 'minimal',
    },
    buf_options = {
      modifiable = false,
      buflisted = false,
      bufhidden = 'wipe',
    },
    win_options = {
      wrap = false,
      number = false,
      cursorline = false,
    },
  })
end

function TestComponent:component_did_mount()
  table.insert(self._log, 'did_mount')
end

function TestComponent:component_will_unmount()
  table.insert(self._log, 'will_unmount')
  if self._element then
    self._element:unmount()
    self._element = nil
  end
end

function TestComponent:get_layout_spec()
  return LayoutSpec.view(self._element, { flex = 1 })
end

function TestComponent:render() end

M.TestComponent = TestComponent

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
