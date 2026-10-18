local Terminal = require('tests.scenario.terminal')

local Editor = {}
Editor.__index = Editor

local DEFAULT_TIMEOUT_MS = 5000

function Editor.start(opts)
  local terminal = Terminal.start(opts)
  return setmetatable({ terminal = terminal, _trace = {} }, Editor)
end

local function record(self, kind, text)
  self._trace[#self._trace + 1] = string.format('%s %q', kind, text)
end

-- Sends keystrokes exactly as a terminal would: ':VGit status<CR>', 'i<C-s>', '<leader>s'.
function Editor:keys(sequence)
  record(self, 'keys', sequence)
  self.terminal:send(sequence)
end

function Editor:cmd(text)
  record(self, 'cmd', text)
  self.terminal:send(':' .. text .. '<CR>')
end

-- The ordered list of keys/cmds sent, for the failure report.
function Editor:trace()
  return self._trace
end

function Editor:settle(timeout_ms)
  return self.terminal:idle(timeout_ms)
end

-- Pumps events until the predicate is true. Fails fast if the child exits, and
-- reports the child's exit code rather than stalling on a dead process.
function Editor:wait_for(predicate, description, timeout_ms)
  local deadline = vim.uv.now() + (timeout_ms or DEFAULT_TIMEOUT_MS)
  while vim.uv.now() < deadline do
    if predicate() then return end
    if not self.terminal:is_alive() then
      error(
        string.format('child exited (code %s) while waiting for %s', tostring(self.terminal._exit_code), description),
        2
      )
    end
    vim.wait(20)
  end
  error('timed out waiting for ' .. description, 2)
end

function Editor:await_text(text, timeout_ms)
  self:wait_for(function()
    return self.terminal:screen():find(text, 1, true) ~= nil
  end, string.format('the screen to show %q', text), timeout_ms)
end

function Editor:await_no_text(text, timeout_ms)
  self:wait_for(function()
    return self.terminal:screen():find(text, 1, true) == nil
  end, string.format('the screen to no longer show %q', text), timeout_ms)
end

function Editor:await_filetype(filetype, timeout_ms)
  self:wait_for(function()
    return self.terminal:rpc_eval('vim.bo.filetype') == filetype
  end, string.format('the current buffer to become %q', filetype), timeout_ms)
end

-- A real user presses a key to clear a "Press ENTER" prompt. Do the same so the
-- child returns to a state where it can be driven and observed again.
function Editor:dismiss(timeout_ms)
  if not self.terminal:at_hit_enter() then return false end
  self:answer('<CR>', timeout_ms)
  return true
end

-- Waits until the child is blocked at a hit-enter prompt, then clears it.
-- Prefer this over dismiss() when a prompt is expected: it tolerates the prompt
-- taking a moment to appear instead of racing it.
function Editor:wait_for_prompt(timeout_ms)
  self:wait_for(function()
    return self.terminal:at_hit_enter()
  end, 'a "Press ENTER" prompt', timeout_ms)
end

-- Sends a key sequence in answer to a prompt and waits for the screen to settle.
function Editor:answer(sequence, timeout_ms)
  self:keys(sequence)
  self:settle(timeout_ms)
end

function Editor:teardown()
  self.terminal:close()
end

return Editor
