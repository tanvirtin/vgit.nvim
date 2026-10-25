local patch = require('vgit.patch')

local eq = assert.are.same

describe('vgit.patch:', function()
  it('should give plain rows, semantic roles and a schema version', function()
    local data = patch.data({
      { filename = 'a.txt', old_lines = { 'local x = 1' }, new_lines = { 'local x = 2' } },
    }, { header = false })

    local kinds, roles = {}, {}

    for _, row in ipairs(data.rows) do
      kinds[#kinds + 1] = row.kind
    end

    for _, hl in ipairs(data.highlights) do
      roles[hl.row .. ':' .. hl.role] = true
    end

    eq(1, data.schema)
    eq('remove', kinds[1])
    eq('add', kinds[2])
    assert.is_true(roles['0:remove'])
    assert.is_true(roles['1:add'])
    eq({
      { row = 0, col = 10, texts = { { '1', 'word_delete' } } },
      { row = 1, col = 10, texts = { { '2', 'word_add' } } },
    }, data.words)
    eq('remove', data.rows[1].number.role)
    eq('add', data.rows[2].number.role)
    eq({ added = 1, removed = 1 }, data.stat)
  end)

  it('should use the pure engine when asked', function()
    local data = patch.data({
      { filename = 'a.txt', old_lines = { 'local x = 1' }, new_lines = { 'local x = 2' } },
    }, { header = false, engine = 'lua' })

    eq('remove', data.rows[1].kind)
    eq('add', data.rows[2].kind)
    eq({ added = 1, removed = 1 }, data.stat)
  end)
end)
