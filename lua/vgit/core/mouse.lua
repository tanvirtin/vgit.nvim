local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')

local mouse = {}

mouse.MAX_CLICK_COUNT = 4

local registry = {}

local function resolve_bufnr(buffer)
  if type(buffer) == 'number' then return buffer end
  if type(buffer) == 'table' and type(buffer.bufnr) == 'number' then return buffer.bufnr end
  return nil
end

local function click_lhs(count)
  if count <= 1 then return '<LeftMouse>' end
  return string.format('<%d-LeftMouse>', count)
end

local function prune_invalid_buffers()
  for bufnr in pairs(registry) do
    if not vim.api.nvim_buf_is_valid(bufnr) then registry[bufnr] = nil end
  end
end

local function build_click_info(count)
  local pos = vim.fn.getmousepos()
  return {
    button = 'left',
    count = count,
    winid = pos.winid,
    lnum = pos.line,
    col = pos.column,
    screenrow = pos.screenrow,
    screencol = pos.screencol,
  }
end

local function place_cursor(info)
  local winid = info.winid
  if type(winid) ~= 'number' or not vim.api.nvim_win_is_valid(winid) then return end
  if info.lnum < 1 then return end

  pcall(vim.api.nvim_set_current_win, winid)

  local buffer = vim.api.nvim_win_get_buf(winid)
  local line_count = vim.api.nvim_buf_line_count(buffer)
  vim.api.nvim_win_set_cursor(winid, { math.min(info.lnum, line_count), math.max(0, info.col - 1) })
end

local function dispatch(bufnr, count)
  local entry = registry[bufnr]
  local state = entry and entry[count]
  if not state then return end

  local info = build_click_info(count)

  if count <= 1 then place_cursor(info) end

  for _, handler in ipairs(state.handlers) do
    handler(info)
  end
end

local function set_click_mapping(bufnr, mode, count, lhs)
  vim.keymap.set(mode, lhs, function()
    dispatch(bufnr, count)
  end, {
    buffer = bufnr,
    nowait = true,
    silent = true,
    desc = string.format('Mouse click x%d', count),
  })
end

function mouse.attach(buffer, opts)
  local bufnr = resolve_bufnr(buffer)
  if not bufnr then return function() end end
  if not opts or type(opts.clicks) ~= 'table' then return function() end end
  if not vim.api.nvim_buf_is_valid(bufnr) then return function() end end

  prune_invalid_buffers()

  local modes = opts.modes or { 'n' }

  local entry = registry[bufnr]
  if not entry then
    entry = {}
    registry[bufnr] = entry
  end

  local owned = {}

  for count, handler in pairs(opts.clicks) do
    if type(count) == 'number' and count >= 1 and count <= mouse.MAX_CLICK_COUNT and type(handler) == 'function' then
      local state = entry[count]
      if not state then
        state = { handlers = {}, modes = {} }
        entry[count] = state
      end

      local wrapped = event.async(handler)
      owned[#owned + 1] = { count = count, handler = wrapped }
      table.insert(state.handlers, wrapped)

      local lhs = click_lhs(count)
      for _, mode in ipairs(modes) do
        if not state.modes[mode] then
          set_click_mapping(bufnr, mode, count, lhs)
          state.modes[mode] = true
        end
      end
    end
  end

  if next(entry) == nil then registry[bufnr] = nil end

  local detached = false
  return function()
    if detached then return end
    detached = true

    local current_entry = registry[bufnr]
    if not current_entry then return end

    for _, registration in ipairs(owned) do
      local state = current_entry[registration.count]
      if state then
        for index, existing in ipairs(state.handlers) do
          if existing == registration.handler then
            table.remove(state.handlers, index)
            break
          end
        end

        if #state.handlers == 0 then
          local lhs = click_lhs(registration.count)
          for mode in pairs(state.modes) do
            pcall(vim.keymap.del, mode, lhs, { buffer = bufnr })
          end
          current_entry[registration.count] = nil
        end
      end
    end

    if next(current_entry) == nil then registry[bufnr] = nil end
  end
end

return mouse
