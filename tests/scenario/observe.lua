local observe = {}

-- Everything here reads what the user would see. The first argument is the
-- scenario context, which carries `editor` (a terminal-backed Editor).
local function terminal(ctx)
  return ctx.editor.terminal
end

function observe.screen(ctx)
  return terminal(ctx):screen()
end

-- Screen as a list of lines with trailing whitespace stripped and trailing blank
-- lines dropped. Stable enough to compare snapshots and to search.
function observe.lines(ctx)
  local raw = terminal(ctx):lines()
  local out = {}
  for i = 1, #raw do
    out[i] = (raw[i]:gsub('%s+$', ''))
  end
  while #out > 0 and out[#out] == '' do
    out[#out] = nil
  end
  return out
end

function observe.frame(ctx)
  return table.concat(observe.lines(ctx), '\n')
end

function observe.contains(ctx, text)
  return terminal(ctx):screen():find(text, 1, true) ~= nil
end

-- Internal state, read over the child's RPC socket (non-blocking, file-based).
-- Use sparingly; prefer the screen. Returns nil if the child is not responsive.
function observe.cwd(ctx)
  return terminal(ctx):rpc_eval('vim.fn.getcwd()')
end

function observe.cursor(ctx)
  return terminal(ctx):rpc_eval_json('{ vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_win_get_cursor(0)[2] }')
end

function observe.buffer_lines(ctx)
  return terminal(ctx):rpc_eval_json('vim.api.nvim_buf_get_lines(0, 0, -1, false)')
end

-- Placed signs in the current buffer as `{ lnum, name, hl }`, 1-indexed. Covers
-- both legacy signs and extmark signs, since vgit renders through extmarks.
function observe.signs(ctx)
  return terminal(ctx):rpc_eval_json([[
    (function()
      local out = {}
      local marks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
      for _, mark in ipairs(marks) do
        local d = mark[4]
        if d.sign_text or d.sign_hl_group then
          out[#out + 1] = { lnum = mark[2] + 1, text = d.sign_text and vim.trim(d.sign_text) or '', hl = d.sign_hl_group or d.number_hl_group }
        end
      end
      return out
    end)()
  ]]) or {}
end

-- Extmarks of any kind on a 1-indexed line, with their highlight groups and
-- virtual text, for decorations that never reach the character grid.
function observe.extmarks(ctx, lnum)
  return terminal(ctx):rpc_eval_json(string.format(
    [[
    (function()
      local out = {}
      local marks = vim.api.nvim_buf_get_extmarks(0, -1, {%d, 0}, {%d, -1}, { details = true })
      for _, mark in ipairs(marks) do
        local d = mark[4]
        local virt, virt_hl = {}, {}
        for _, chunk in ipairs(d.virt_text or {}) do
          virt[#virt + 1] = chunk[1]
          if chunk[2] then virt_hl[#virt_hl + 1] = chunk[2] end
        end
        out[#out + 1] = { hl = d.hl_group, virt_text = table.concat(virt), virt_hl = virt_hl, sign_hl = d.sign_hl_group }
      end
      return out
    end)()
  ]],
    lnum - 1,
    lnum - 1
  )) or {}
end

function observe.repository_path(ctx)
  return terminal(ctx):rpc_eval([[
    (function()
      local repo = require('vgit.git.repository').current()
      return repo and repo:get_path() or nil
    end)()
  ]])
end

return observe
