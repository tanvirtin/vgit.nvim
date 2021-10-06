local M = {}

M.assert = function(cond, msg)
  if not cond then
    error(debug.traceback(msg))
  end
end

return M
