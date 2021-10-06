local assert = require('vgit.assertion').assert
local M = {}

M.retrieve = function(cmd, ...)
  if type(cmd) == 'function' then
    return cmd(...)
  end
  return cmd
end

M.round = function(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

M.readonly = function(tbl)
  return setmetatable({}, {
    __index = function(_, k)
      return tbl[k]
    end,
    __newindex = function()
      assert(false, 'Table is readonly')
    end,
    __metatable = {},
    __len = function()
      return #tbl
    end,
    __tostring = function()
      return tostring(tbl)
    end,
    __call = function(_, ...)
      return tbl(...)
    end,
  })
end

return M
