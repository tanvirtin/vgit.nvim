local utils = require('vgit.utils')
local render_store = require('vgit.stores.render_store')
local DiffPreview = require('vgit.previews.DiffPreview')
local GutterBlamePreview = require('vgit.previews.GutterBlamePreview')
local preview_store = require('vgit.stores.preview_store')
local HistoryPreview = require('vgit.previews.HistoryPreview')
local HunkPreview = require('vgit.previews.HunkPreview')
local BlamePreview = require('vgit.previews.BlamePreview')
local ProjectDiffPreview = require('vgit.previews.ProjectDiffPreview')
local virtual_text = require('vgit.virtual_text')
local buffer = require('vgit.buffer')
local sign = require('vgit.sign')
local scheduler = require('plenary.async.util').scheduler
local void = require('plenary.async.async').void

local M = {}

local current_hunk_mark_timer_id = nil

M.constants = utils.readonly({
  blame_ns_id = vim.api.nvim_create_namespace('tanvirtin/vgit.nvim/blame'),
  current_hunk_mark_ns_id = vim.api.nvim_create_namespace(
    'tanvirtin/vgit.nvim/current_hunk_mark_ns_id'
  ),
  blame_line_id = 1,
})

M.render_current_hunk_mark = function(buf, selected, num_hunks)
  M.hide_current_hunk_mark(buf)
  scheduler()
  local epoch = 1000
  if current_hunk_mark_timer_id then
    vim.fn.timer_stop(current_hunk_mark_timer_id)
    current_hunk_mark_timer_id = nil
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  scheduler()
  virtual_text.transpose_text(
    buf,
    string.format(' %s/%s Changes ', selected, num_hunks),
    M.constants.current_hunk_mark_ns_id,
    'Comment',
    cursor[1] - 1,
    0,
    'right_align'
  )
  current_hunk_mark_timer_id = vim.fn.timer_start(
    epoch,
    void(function()
      if buffer.is_valid(buf) then
        scheduler()
        virtual_text.clear(buf, M.constants.current_hunk_mark_ns_id)
      end
      vim.fn.timer_stop(current_hunk_mark_timer_id)
      current_hunk_mark_timer_id = nil
    end)
  )
end

M.render_blame_line = function(buf, blame, lnum, git_config)
  if buffer.is_valid(buf) then
    local virt_text = render_store.get('line_blame').format(blame, git_config)
    if type(virt_text) == 'string' then
      pcall(virtual_text.add, buf, M.constants.blame_ns_id, lnum - 1, 0, {
        id = M.constants.blame_line_id,
        virt_text = { { virt_text, render_store.get('line_blame').hl } },
        virt_text_pos = 'eol',
        hl_mode = 'combine',
      })
    end
  end
end

M.render_hunk_signs = function(buf, hunks)
  scheduler()
  if buffer.is_valid(buf) then
    for i = 1, #hunks do
      scheduler()
      local hunk = hunks[i]
      for j = hunk.start, hunk.finish do
        sign.place(
          buf,
          (hunk.type == 'remove' and j == 0) and 1 or j,
          render_store.get('sign').hls[hunk.type],
          render_store.get('sign').priority
        )
        scheduler()
      end
      scheduler()
    end
  end
end

M.render_blame_preview = function(fetch)
  preview_store.clear()
  local blame_preview = BlamePreview:new()
  preview_store.set(blame_preview)
  blame_preview:mount()
  blame_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  blame_preview:set_loading(false)
  scheduler()
  blame_preview.err = err
  blame_preview.data = data
  blame_preview:render()
  scheduler()
end

M.render_gutter_blame_preview = function(fetch, filetype)
  preview_store.clear()
  local gutter_blame_preview = GutterBlamePreview:new({ filetype = filetype })
  preview_store.set(gutter_blame_preview)
  gutter_blame_preview:mount()
  gutter_blame_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  gutter_blame_preview:set_loading(false)
  scheduler()
  gutter_blame_preview.err = err
  gutter_blame_preview.data = data
  gutter_blame_preview:render()
  scheduler()
end

M.render_hunk_preview = function(fetch, filetype)
  preview_store.clear()
  local current_lnum = vim.api.nvim_win_get_cursor(0)[1]
  local hunk_preview = HunkPreview:new({ filetype = filetype })
  preview_store.set(hunk_preview)
  hunk_preview:mount()
  hunk_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  hunk_preview:set_loading(false)
  scheduler()
  hunk_preview.err = err
  hunk_preview.data = data
  hunk_preview.selected = current_lnum
  hunk_preview:render()
  scheduler()
end

M.render_diff_preview = function(fetch, filetype, layout_type)
  preview_store.clear()
  local current_lnum = vim.api.nvim_win_get_cursor(0)[1]
  local diff_preview = DiffPreview:new({
    filetype = filetype,
    layout_type = layout_type,
    temporary = layout_type == 'horizontal',
  })
  preview_store.set(diff_preview)
  diff_preview:mount()
  diff_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  diff_preview:set_loading(false)
  scheduler()
  diff_preview.err = err
  diff_preview.data = data
  diff_preview.selected = current_lnum
  diff_preview:render()
  scheduler()
end

M.render_history_preview = function(fetch, filetype, layout_type)
  preview_store.clear()
  local history_preview = HistoryPreview:new({
    filetype = filetype,
    layout_type = layout_type,
    selected = 0,
  })
  preview_store.set(history_preview)
  history_preview:mount()
  history_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  history_preview:set_loading(false)
  scheduler()
  history_preview.err = err
  history_preview.data = data
  history_preview:render()
  scheduler()
end

M.rerender_history_preview = function(fetch, selected)
  selected = selected - 1
  local history_preview = preview_store.get()
  scheduler()
  if history_preview.selected == selected then
    return
  end
  scheduler()
  history_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  history_preview:set_loading(false)
  scheduler()
  history_preview.err = err
  history_preview.data = data
  history_preview.selected = selected
  history_preview:render()
  scheduler()
end

M.render_project_diff_preview = function(fetch, layout_type)
  preview_store.clear()
  local project_diff_preview = ProjectDiffPreview:new({
    layout_type = layout_type,
    selected = 0,
  })
  preview_store.set(project_diff_preview)
  project_diff_preview:mount()
  project_diff_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  project_diff_preview:set_loading(false)
  scheduler()
  project_diff_preview.err = err
  project_diff_preview.data = data
  project_diff_preview:render()
  scheduler()
end

M.rerender_project_diff_preview = function(fetch, selected)
  selected = selected - 1
  local project_diff_preview = preview_store.get()
  scheduler()
  if project_diff_preview.selected == selected then
    local data = project_diff_preview.data
    if not data then
      return
    end
    local changed_files = data.changed_files
    if not changed_files then
      return
    end
    local changed_file = changed_files[selected + 1]
    if not changed_file then
      return
    end
    local invalid_status = {
      ['AD'] = true,
      [' D'] = true,
    }
    if invalid_status[changed_file.status] then
      return
    end
    M.hide_preview()
    vim.cmd(string.format('e %s', changed_file.filename))
    return
  end
  project_diff_preview:set_loading(true)
  scheduler()
  local err, data = fetch()
  scheduler()
  project_diff_preview:set_loading(false)
  scheduler()
  project_diff_preview.err = err
  project_diff_preview.data = data
  project_diff_preview.selected = selected
  project_diff_preview:render()
  scheduler()
end

M.hide_current_hunk_mark = function(buf)
  if current_hunk_mark_timer_id then
    vim.fn.timer_stop(current_hunk_mark_timer_id)
    current_hunk_mark_timer_id = nil
    if buffer.is_valid(buf) then
      virtual_text.clear(buf, M.constants.current_hunk_mark_ns_id)
    end
  end
end

M.hide_blame_line = function(buf)
  if buffer.is_valid(buf) then
    pcall(
      virtual_text.delete,
      buf,
      M.constants.blame_ns_id,
      M.constants.blame_line_id
    )
  end
end

M.hide_hunk_signs = function(buf)
  scheduler()
  if buffer.is_valid(buf) then
    sign.unplace(buf)
    scheduler()
  end
end

M.hide_preview = function()
  local preview = preview_store.get()
  if not vim.tbl_isempty(preview) then
    preview:unmount()
    preview_store.set({})
  end
end

M.hide_windows = function(wins)
  local preview = preview_store.get()
  if not vim.tbl_isempty(preview) then
    preview_store.clear()
  end
  local existing_wins = vim.api.nvim_list_wins()
  for i = 1, #wins do
    local win = wins[i]
    if
      vim.api.nvim_win_is_valid(win) and vim.tbl_contains(existing_wins, win)
    then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

return M
