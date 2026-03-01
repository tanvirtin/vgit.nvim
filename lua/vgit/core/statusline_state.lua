local HUNK_CLEAR_MS = 2000

local state = {
  hunk_index = nil,
  hunk_count = nil,
  diff_stats = nil,
  branch = nil,
}

local hunk_timer = nil

local statusline_state = {}

local function redraw()
  vim.cmd('redrawstatus')
end

local function clear_hunk()
  if hunk_timer then
    hunk_timer:stop()
    if not hunk_timer:is_closing() then hunk_timer:close() end
    hunk_timer = nil
  end
  state.hunk_index = nil
  state.hunk_count = nil
  vim.g.vgit_hunk_index = nil
  vim.g.vgit_hunk_count = nil
  redraw()
end

function statusline_state.set_hunk(hunk)
  if hunk_timer then
    hunk_timer:stop()
    if not hunk_timer:is_closing() then hunk_timer:close() end
    hunk_timer = nil
  end

  local index = hunk.index
  local count = hunk.count
  state.hunk_index = index
  state.hunk_count = count
  vim.g.vgit_hunk_index = index
  vim.g.vgit_hunk_count = count
  redraw()

  hunk_timer = vim.uv.new_timer()
  hunk_timer:start(HUNK_CLEAR_MS, 0, vim.schedule_wrap(clear_hunk))
end

function statusline_state.set_diff_stats(stats)
  state.diff_stats = stats
  if stats then
    vim.g.vgit_added = stats.added
    vim.g.vgit_removed = stats.removed
    vim.g.vgit_changed = stats.changed
  else
    vim.g.vgit_added = nil
    vim.g.vgit_removed = nil
    vim.g.vgit_changed = nil
  end
  redraw()
end

function statusline_state.set_branch(name)
  state.branch = name
  vim.g.vgit_branch = name
  redraw()
end

function statusline_state.reset()
  if hunk_timer then
    hunk_timer:stop()
    hunk_timer:close()
    hunk_timer = nil
  end
  state.hunk_index = nil
  state.hunk_count = nil
  state.diff_stats = nil
  state.branch = nil
  vim.g.vgit_hunk_index = nil
  vim.g.vgit_hunk_count = nil
  vim.g.vgit_added = nil
  vim.g.vgit_removed = nil
  vim.g.vgit_changed = nil
  vim.g.vgit_branch = nil
end

function statusline_state.get_hunk()
  if state.hunk_index and state.hunk_count then return { index = state.hunk_index, count = state.hunk_count } end
  return nil
end

function statusline_state.get_diff_stats()
  return state.diff_stats
end

function statusline_state.get_branch()
  return state.branch
end

return statusline_state
