local keys = require('tests.scenario.keys')

local Terminal = {}
Terminal.__index = Terminal

local IDLE_MS = 150
local STARTUP_MS = 10000
local RPC_MS = 2000

local function socket_path(root)
  return root .. '/nvim.sock'
end

local function setup_cmd(config)
  if not config or next(config) == nil then return 'lua require("vgit").setup({})' end
  -- Long-bracket the JSON so quotes/escapes in the config cannot break the cmd.
  return 'lua require("vgit").setup(vim.json.decode([==[' .. vim.json.encode(config) .. ']==]))'
end

-- Starts a real Neovim inside a terminal buffer of the test process. The terminal
-- buffer is the child's own pty screen, so its lines are exactly what a user sees.
function Terminal.start(opts)
  local root = opts.root
  local cwd = opts.cwd
  local sock = socket_path(root)

  local win_h = vim.api.nvim_win_get_height(0)
  local win_w = vim.api.nvim_win_get_width(0)
  vim.cmd('enew')
  local bufnr = vim.api.nvim_get_current_buf()

  -- stty -ixon so <C-s> reaches Neovim instead of being eaten as pty XOFF flow control.
  local argv = {
    'sh',
    '-c',
    'stty -ixon 2>/dev/null; exec "$@"',
    'sh',
    vim.v.progpath,
    '--clean',
    '--listen',
    sock,
    '--cmd',
    'set rtp^=' .. opts.plugin_root,
    '-c',
    setup_cmd(opts.config),
  }

  local job = vim.fn.termopen(argv, { cwd = cwd, env = opts.env })
  assert(job > 0, 'failed to start child nvim')

  local self = setmetatable({
    job = job,
    bufnr = bufnr,
    sock = sock,
    root = root,
    rows = win_h,
    cols = win_w,
    quiet_ms = IDLE_MS,
    _rpc = nil,
    _rpc_seq = 0,
    _exit_code = nil,
  }, Terminal)

  self:_await_rpc()
  return self
end

function Terminal:_await_rpc()
  local ready = vim.wait(STARTUP_MS, function()
    if self._rpc then return true end
    if not vim.uv.fs_stat(self.sock) then return false end
    local ok, chan = pcall(vim.fn.sockconnect, 'pipe', self.sock, { rpc = true })
    if ok and chan and chan > 0 then self._rpc = chan end
    return self._rpc ~= nil
  end, 20)
  assert(ready, 'child nvim did not start listening on ' .. self.sock)
end

-- Non-blocking liveness check. A crashed child would otherwise stall every wait
-- until the 30s watchdog; detecting it lets us fail fast with the exit code.
function Terminal:is_alive()
  if self._exit_code ~= nil then return false end
  local ok, codes = pcall(vim.fn.jobwait, { self.job }, 0)
  if not ok or not codes or codes[1] == nil then return true end
  if codes[1] ~= -1 then
    self._exit_code = codes[1]
    return false
  end
  return true
end

function Terminal:send(sequence)
  vim.fn.chansend(self.job, keys.encode(sequence))
end

function Terminal:lines()
  return vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
end

function Terminal:screen()
  return table.concat(self:lines(), '\n')
end

-- Waits until the screen stops changing, which is how a user knows the UI is ready.
-- Returns { ok, reason } where reason is 'stable' | 'timeout' | 'exited'.
function Terminal:idle(timeout_ms)
  timeout_ms = timeout_ms or STARTUP_MS
  local last = self:screen()
  local stable_since = vim.uv.now()
  local deadline = vim.uv.now() + timeout_ms
  while vim.uv.now() < deadline do
    if not self:is_alive() then return { ok = false, reason = 'exited', exit_code = self._exit_code } end
    vim.wait(20)
    local current = self:screen()
    if current ~= last then
      last = current
      stable_since = vim.uv.now()
    elseif vim.uv.now() - stable_since >= self.quiet_ms then
      return { ok = true, reason = 'stable' }
    end
  end
  return { ok = false, reason = 'timeout' }
end

-- True while the child is blocked at a hit-enter prompt ("Press ENTER ...").
-- In that state it does not service RPC, so never use blocking rpcrequest.
function Terminal:at_hit_enter()
  local lines = self:lines()
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line and line:match('%S') then return line:find('Press ENTER', 1, true) ~= nil end
  end
  return false
end

function Terminal:_next_rpc_path(tag)
  self._rpc_seq = self._rpc_seq + 1
  return string.format('%s/rpc_%s_%d.txt', self.root, tag, self._rpc_seq)
end

function Terminal:_await_rpc_file(path, timeout_ms)
  local ok = vim.wait(timeout_ms or RPC_MS, function()
    return vim.uv.fs_stat(path) ~= nil
  end, 20)
  return ok
end

-- Evaluates a Lua expression inside the child without ever blocking the parent.
-- The child writes the tostring result to a file; we poll that file with a timeout.
function Terminal:rpc_eval(expr, timeout_ms)
  if not self._rpc then return nil end

  local path = self:_next_rpc_path('expr')
  local code = string.format(
    'local ok, res = pcall(function() return %s end)\n'
      .. 'local f = io.open(%q, \'w\')\n'
      .. 'if f then f:write(ok and tostring(res) or (\'ERR: \' .. tostring(res))) f:close() end',
    expr,
    path
  )

  pcall(vim.rpcnotify, self._rpc, 'nvim_exec_lua', code, {})

  if not self:_await_rpc_file(path, timeout_ms) then return nil end

  local out = table.concat(vim.fn.readfile(path), '\n')
  if out:sub(1, 5) == 'ERR: ' then error(out, 2) end
  return out
end

-- Like rpc_eval, but round-trips the result through vim.json so tables, numbers
-- and booleans survive intact instead of being flattened by tostring.
function Terminal:rpc_eval_json(expr, timeout_ms)
  if not self._rpc then return nil end

  local path = self:_next_rpc_path('json')
  local code = string.format(
    'local ok, res = pcall(function() return %s end)\n'
      .. 'local payload = { ok = ok, value = ok and res or tostring(res) }\n'
      .. 'local f = io.open(%q, \'w\')\n'
      .. 'if f then f:write(vim.json.encode(payload)) f:close() end',
    expr,
    path
  )

  pcall(vim.rpcnotify, self._rpc, 'nvim_exec_lua', code, {})

  if not self:_await_rpc_file(path, timeout_ms) then return nil end

  local payload = vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  if not payload.ok then error(payload.value, 2) end
  return payload.value
end

-- Reads :messages without blocking. A wedged child (e.g. at a hit-enter prompt)
-- would hang a plain rpcrequest, so ask it to redir to a file and read that.
function Terminal:messages()
  if not self._rpc then return '' end
  local path = self:_next_rpc_path('messages')
  pcall(vim.rpcnotify, self._rpc, 'nvim_command', 'redir! > ' .. path .. ' | silent messages | redir END')
  vim.wait(200, function()
    return false
  end, 10)
  local stat = vim.uv.fs_stat(path)
  if not stat then return '' end
  return table.concat(vim.fn.readfile(path), '\n')
end

-- Non-blocking: the child may be stuck at a hit-enter prompt or otherwise busy, so
-- never wait on an RPC reply here. Notify, then hard-stop the job.
function Terminal:close()
  if self._rpc then
    pcall(vim.rpcnotify, self._rpc, 'nvim_command', 'qa!')
    pcall(vim.fn.chanclose, self._rpc)
  end
  pcall(vim.fn.jobstop, self.job)
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    pcall(vim.api.nvim_buf_delete, self.bufnr, { force = true })
  end
  self._rpc = nil
end

return Terminal
