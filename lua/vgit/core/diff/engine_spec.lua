local engine = require('vgit.core.diff.engine')

local eq = assert.are.same

local function shape(hunks)
  local result = {}

  for _, hunk in ipairs(hunks) do
    result[#result + 1] = {
      header = hunk.header,
      top = hunk.top,
      bot = hunk.bot,
      type = hunk.type,
      diff = hunk.diff,
      stat = hunk.stat,
    }
  end

  return result
end

describe('engine:', function()
  describe('live', function()
    local cases = {
      { 'no change', { 'a', 'b' }, { 'a', 'b' } },
      { 'replace', { 'a', 'b', 'c' }, { 'a', 'B', 'c' } },
      { 'insert at the start', { 'a', 'b' }, { 'x', 'a', 'b' } },
      { 'insert at the end', { 'a', 'b' }, { 'a', 'b', 'x' } },
      { 'insert in the middle', { 'a', 'b' }, { 'a', 'x', 'b' } },
      { 'delete at the start', { 'a', 'b' }, { 'b' } },
      { 'delete at the end', { 'a', 'b' }, { 'a' } },
      { 'delete in the middle', { 'a', 'b', 'c' }, { 'a', 'c' } },
      { 'two changes', { 'a', 'b', 'c', 'd' }, { 'a', 'X', 'c', 'Y' } },
      { 'replace every line', { 'a', 'b' }, { 'x', 'y' } },
    }

    for _, case in ipairs(cases) do
      it('should match vim.diff for ' .. case[1], function()
        local vim_hunks = engine.live(case[2], case[3], { engine = 'vim' })
        local lua_hunks = engine.live(case[2], case[3], { engine = 'lua' })

        eq(shape(vim_hunks), shape(lua_hunks))
      end)
    end
  end)

  describe('custom', function()
    it('should build an untracked hunk', function()
      local hunks = engine.custom({ 'a', 'b' }, { untracked = true })

      eq(1, #hunks)
      eq('add', hunks[1].type)
      eq('@@ -0,0 +1,2 @@', hunks[1].header)
      eq({ '+a', '+b' }, hunks[1].diff)
      eq({ added = 2, removed = 0 }, hunks[1].stat)
    end)

    it('should build a deleted hunk', function()
      local hunks = engine.custom({ 'a' }, { deleted = true })

      eq(1, #hunks)
      eq('remove', hunks[1].type)
      eq('@@ -1,1 +0,0 @@', hunks[1].header)
      eq({ '-a' }, hunks[1].diff)
      eq({ added = 0, removed = 1 }, hunks[1].stat)
    end)
  end)
end)
