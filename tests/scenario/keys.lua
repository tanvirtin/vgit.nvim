local keys = {}

-- Keys whose pty bytes are not derivable from a modifier rule.
local NAMED = {
  ['<CR>'] = '\r',
  ['<Enter>'] = '\r',
  ['<NL>'] = '\n',
  ['<Esc>'] = '\27',
  ['<BS>'] = '\127',
  ['<Tab>'] = '\t',
  ['<Space>'] = ' ',
  ['<NUL>'] = '\0',
  ['<Del>'] = '\27[3~',
  ['<leader>'] = '\\',
  ['<Up>'] = '\27[A',
  ['<Down>'] = '\27[B',
  ['<Right>'] = '\27[C',
  ['<Left>'] = '\27[D',
  ['<Home>'] = '\27[H',
  ['<End>'] = '\27[F',
  ['<PageUp>'] = '\27[5~',
  ['<PageDown>'] = '\27[6~',
  ['<Insert>'] = '\27[2~',
}

-- Symbol controls that do not follow the "letter - 96" rule.
local CTRL_SYMBOLS = {
  ['['] = '\27',
  ['\\'] = '\28',
  [']'] = '\29',
  ['^'] = '\30',
  ['_'] = '\31',
  ['?'] = '\127',
}

local function decode_modified(inner)
  local mod, base = inner:match('^([CSMAmcsa])%-(.+)$')
  if not mod or #base ~= 1 then
    -- Ctrl+Space is the one multi-character base worth supporting.
    if (mod == 'C' or mod == 'c') and base and base:lower() == 'space' then return '\0' end
    return nil
  end

  local m = mod:upper()
  if m == 'C' then
    if base:match('%a') then return string.char(base:lower():byte() - 96) end
    return CTRL_SYMBOLS[base]
  elseif m == 'S' then
    return base:upper()
  elseif m == 'M' or m == 'A' then
    return '\27' .. base
  end
  return nil
end

local function decode_token(token)
  if NAMED[token] then return NAMED[token] end
  return decode_modified(token:sub(2, -2))
end

-- Translates a key sequence such as ':VGit status<CR>', 'i<C-s>' or '<leader>s'
-- into the bytes a terminal would write to the child's pty. Plain characters pass
-- through untouched.
--
-- A `<...>` token that is not recognised is an error rather than literal text: a
-- typo like `<C-xx>` should fail loudly, not silently type the angle brackets.
-- Pass `{ literal = true }` to opt out for text that genuinely contains `<...>`.
function keys.encode(sequence, opts)
  opts = opts or {}
  local out = {}
  local i = 1
  while i <= #sequence do
    local rest = sequence:sub(i)
    local token = rest:match('^(<[^>]+>)')

    if token then
      local decoded = decode_token(token)
      if not decoded then
        if not opts.literal then error(string.format('keys.encode: unknown key token %q', token), 2) end
        decoded = token
      end
      out[#out + 1] = decoded
      i = i + #token
    else
      out[#out + 1] = sequence:sub(i, i)
      i = i + 1
    end
  end
  return table.concat(out)
end

return keys
