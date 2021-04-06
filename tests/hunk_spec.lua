local Hunk = require('git.Hunk')

local vim = vim
local it = it
local describe = describe

describe('Hunk:', function()
    local path = 'path/to/file'
    local headers = {
        add = '@@ -17,0 +18,15 @@ foo bar',
        remove = '@@ -9,9 +8,0 @@ @@ foo bar',
        change = '@@ -10,7 +10,7 @@ foo bar',
        invalid = '@@ --10,-1 +-10,-7 @@ foo bar',
        invalid_zero = '@@ -0,0 +0,0 @@ foo bar',
    }

    describe('new', function()
        it('should create a hunk from given parameters', function()
            local hunk = Hunk:new(path, headers['add'])
            assert.are.same(type(hunk), 'table')
            local hunk_keys = { 'filepath', 'start', 'finish', 'type', 'diff' }
            for key, _ in pairs(hunk) do
                assert(vim.tbl_contains(hunk_keys, key))
            end
        end)

       it("should create a hunk with correct type", function()
            assert.are.same(Hunk:new(path, headers['add']).type, 'add')
            assert.are.same(Hunk:new(path, headers['remove']).type, 'remove')
            assert.are.same(Hunk:new(path, headers['change']).type, 'change')
        end)

       it("should create a hunk with correct filepath", function()
            assert.are.same(Hunk:new(path, headers['add']).filepath, path)
            assert.are.same(Hunk:new(path, headers['remove']).filepath, path)
            assert.are.same(Hunk:new(path, headers['change']).filepath, path)
        end)

       it("should create a hunk with correct start and finish", function()
            local add_hunk = Hunk:new(path, headers['add'])
            assert.are.same(add_hunk.start, 18)
            assert.are.same(add_hunk.finish, 18 + 15 - 1)

            local remove_hunk = Hunk:new(path, headers['remove'])
            assert.are.same(remove_hunk.start, 8)
            assert.are.same(remove_hunk.finish, 8)

            local change_hunk = Hunk:new(path, headers['change'])
            assert.are.same(change_hunk.start, 10)
            assert.are.same(change_hunk.finish, 10 + 7 - 1)
        end)
    end)

    describe('add_line', function()
        it('should add lines accordingly', function()
            local hunk = Hunk:new(path, headers['add'])
            local lines = {
                'hello',
                'world',
                'this is program speaking',
            }

            for _, line in ipairs(lines) do
                hunk:add_line(line)
            end

            for i, line in ipairs(hunk.diff) do
                assert.are.same(lines[i], line)
            end

            assert.are.same(#hunk.diff, #lines)
        end)
    end)
end)
