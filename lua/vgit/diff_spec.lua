local diff = require('vgit.diff')

local eq = assert.are.same

describe('vgit.diff:', function()
  it('should give plain changes, word roles and a schema version', function()
    local data = diff.data({ 'local a = 1' }, { 'local a = 2' }, { layout = 'split' })
    local changes, words = {}, {}

    for _, change in ipairs(data.changes) do
      changes[change.buftype] = change
    end

    for _, word in ipairs(data.words) do
      words[word.buftype] = word
    end

    eq(1, data.schema)
    eq({ lnum = 1, buftype = 'previous', type = 'remove' }, changes.previous)
    eq({ lnum = 1, buftype = 'current', type = 'add' }, changes.current)
    eq({ buftype = 'previous', lnum = 1, col = 10, texts = { { '1', 'word_delete' } } }, words.previous)
    eq({ buftype = 'current', lnum = 1, col = 10, texts = { { '2', 'word_add' } } }, words.current)
    eq({ added = 1, removed = 1 }, data.stat)
  end)

  it('should use the pure engine when asked', function()
    local data = diff.data({ 'a', 'b' }, { 'a', 'c' }, { layout = 'split', engine = 'lua' })

    eq(1, data.schema)
    eq({ added = 1, removed = 1 }, data.stat)
  end)
end)
