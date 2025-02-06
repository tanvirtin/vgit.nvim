local keymap = {}

function keymap.set(opts, callback)
  opts = opts or {}

  local key = opts.key
  local mode = opts.mode
  local desc = opts.desc
  local mapping = opts.mapping
  local silent = opts.silent == nil and true or opts.silent
  local noremap = opts.noremap == nil and true or opts.noremap

  if mapping then
    if type(mapping) == 'table' then
      key = mapping.key
      desc = mapping.desc
    else
      key = mapping
    end
  end

  if type(callback) == 'string' then
    local command = callback

    if not desc then desc = 'VGit:' .. command end

    vim.api.nvim_set_keymap(mode, key, string.format('<Cmd>lua require("vgit").%s()<CR>', command), {
      desc = desc,
      silent = silent,
      noremap = noremap,
    })

    return keymap
  end

  vim.keymap.set(mode, key, callback, {
    desc = desc,
    silent = silent,
    noremap = noremap,
  })

  return keymap
end

function keymap.buffer_set(buffer, opts, callback)
  opts = opts or {}

  local key = opts.key
  local mode = opts.mode
  local desc = opts.desc
  local mapping = opts.mapping
  local silent = opts.silent == nil and true or opts.silent
  local noremap = opts.noremap == nil and true or opts.noremap

  if mapping then
    if type(mapping) == 'table' then
      key = mapping.key
      desc = mapping.desc
    else
      key = mapping
    end
  end

  vim.keymap.set(mode, key, callback, {
    desc = desc,
    silent = silent,
    noremap = noremap,
    buffer = buffer.bufnr,
  })

  return keymap
end

function keymap.define(keymaps)
  for commands, callback in pairs(keymaps) do
    if type(callback) == 'table' then
      local config = callback
      keymap.set(config, config.handler)
    else
      commands = vim.split(commands, ' ')
      local config = {
        mode = commands[1],
        key = commands[2],
      }
      keymap.set(config, callback)
    end
  end

  return keymap
end

function keymap.find(command)
  local keybindings = {}
  local modes = { 'n', 'i', 'v', 'x', 's', 'o', 't', 'c' }

  for _, mode in ipairs(modes) do
    local keymaps = vim.api.nvim_get_keymap(mode)

    for _, binding in ipairs(keymaps) do
      if binding.rhs and string.find(binding.rhs, command) then
        table.insert(keybindings, {
          mode = mode,
          lhs = binding.lhs,
          rhs = binding.rhs,
        })
      end
    end
  end

  return keybindings
end

return keymap
