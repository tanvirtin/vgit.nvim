local M = {}

function M.parse_args(definitions)
  local parsed = {}
  local positional = {}

  local i = 1
  while i <= #arg do
    local current = arg[i]
    local matched = false

    for flag, def in pairs(definitions) do
      local flags = def.flags or { flag }

      for _, f in ipairs(flags) do
        if current == f then
          matched = true

          if def.type == 'boolean' then
            parsed[def.name] = true
            i = i + 1
          elseif def.type == 'string' then
            local value = arg[i + 1]
            if not value then
              error('Option ' .. current .. ' requires a value')
            end
            parsed[def.name] = value
            i = i + 2
          elseif def.type == 'action' then
            def.action()
          end

          break
        end
      end

      if matched then break end
    end

    if not matched then
      if current:sub(1, 1) == '-' then
        error('Unknown option: ' .. current)
      else
        table.insert(positional, current)
        i = i + 1
      end
    end
  end

  parsed._positional = positional
  return parsed
end

return M
