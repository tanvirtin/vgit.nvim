local git = require('git.git')

local it = it
local vim = vim
local describe = describe
local after_each = after_each

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local lines = {}
    for line in io.lines(path) do
        table.insert(lines, line)
    end
    file:close()
    return lines;
end

local function clear_file_content(path)
    os.execute(string.format('rm -rf %s', path))
    os.execute(string.format('touch %s', path))
end

local function add_line_to_file(line, path)
    os.execute(string.format('echo "%s" >> %s', line, path))
end

describe('git:', function()

    describe('create_hunk', function()
        local headers = {
            add = '@@ -17,0 +18,15 @@ foo bar',
            remove = '@@ -9,9 +8,0 @@ @@ foo bar',
            change = '@@ -10,7 +10,7 @@ foo bar',
            invalid = '@@ --10,-1 +-10,-7 @@ foo bar',
            invalid_zero = '@@ -0,0 +0,0 @@ foo bar',
        }

        it('should create a hunk from given parameters', function()
            local hunk = git.create_hunk(headers['add'])
            assert.are.same(type(hunk), 'table')
            local hunk_keys = { 'start', 'finish', 'type', 'diff' }
            for key, _ in pairs(hunk) do
                assert(vim.tbl_contains(hunk_keys, key))
            end
        end)

       it('should create a hunk with correct type', function()
            assert.are.same(git.create_hunk(headers['add']).type, 'add')
            assert.are.same(git.create_hunk(headers['remove']).type, 'remove')
            assert.are.same(git.create_hunk(headers['change']).type, 'change')
        end)

       it('should create a hunk with correct start and finish', function()
            local add_hunk = git.create_hunk(headers['add'])
            assert.are.same(add_hunk.start, 18)
            assert.are.same(add_hunk.finish, 18 + 15 - 1)

            local remove_hunk = git.create_hunk(headers['remove'])
            assert.are.same(remove_hunk.start, 8)
            assert.are.same(remove_hunk.finish, 8)

            local change_hunk = git.create_hunk(headers['change'])
            assert.are.same(change_hunk.start, 10)
            assert.are.same(change_hunk.finish, 10 + 7 - 1)
        end)

        it('will allow lines to be added to the diff of the hunk created', function()
            local hunk = git.create_hunk(headers['add'])
            local lines = {
                'hello',
                'world',
                'this is program speaking',
            }

            for _, line in ipairs(lines) do
                table.insert(hunk.diff, line)
            end

            for i, line in ipairs(hunk.diff) do
                assert.are.same(lines[i], line)
            end

            assert.are.same(#hunk.diff, #lines)
        end)

    end)

    describe('hunks', function()
        local path = '.gitignore'
        local lines = read_file(path)

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', path))
        end)

        it('should return only added hunks', function()
            clear_file_content(path)
            for i = 1, #lines do
                add_line_to_file(lines[i], path)
                add_line_to_file('#', path)
            end
            local error = nil
            local results = nil
            local job = git.hunks(path, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, #lines)
            for _, hunk in pairs(results) do
                assert.are.same(hunk.type, 'add')
            end
        end)

        it('should return only removed hunks', function()
            local counter = 0
            clear_file_content(path)
            for i = 1, #lines do
                if i % 2 == 0 then
                    add_line_to_file(lines[i], path)
                else
                    counter = counter + 1
                end
            end
            local error = nil
            local results = nil
            local job = git.hunks(path, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, counter)
            for _, hunk in pairs(results) do
                assert.are.same(hunk.type, 'remove')
            end
        end)

        it('should return only changed hunks', function()
            local counter = 0
            clear_file_content(path)
            for i = 1, #lines do
                if i % 2 == 0 then
                    add_line_to_file(lines[i], path)
                else
                    add_line_to_file(lines[i] .. '#########', path)
                    counter = counter + 1
                end
            end
            local error = nil
            local results = nil
            local job = git.hunks(path, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, counter)
            for _, hunk in pairs(results) do
                assert.are.same(hunk.type, 'change')
            end
        end)

        it('should return all possible hunks', function()
            local added_indices = {}
            local changed_indices = {}
            local removed_indices = {}
            clear_file_content(path)
            for i = 1, #lines do
                if i == 1 then
                    add_line_to_file('########', path)
                    add_line_to_file(lines[i], path)
                    table.insert(added_indices, i)
                elseif i == 2 then
                    add_line_to_file(lines[i] .. '#########', path)
                    table.insert(changed_indices, i)
                elseif i == 4 then
                    table.insert(removed_indices, i)
                else
                    add_line_to_file(lines[i], path)
                end
            end
            local error = nil
            local results = nil
            local job = git.hunks(path, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, 3)
            assert.are.same(results[1].type, 'add')
            assert.are.same(results[2].type, 'change')
            assert.are.same(results[3].type, 'remove')
        end)

    end)

end)
