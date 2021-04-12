local git = require('git.git')

local it = it
local vim = vim
local describe = describe
local after_each = after_each

local function read_file(filename)
    local file = io.open(filename, "rb")
    if not file then return nil end
    local lines = {}
    for line in io.lines(filename) do
        table.insert(lines, line)
    end
    file:close()
    return lines;
end

local function clear_file_content(filename)
    os.execute(string.format('rm -rf %s', filename))
    os.execute(string.format('touch %s', filename))
end

local function add_line_to_file(line, filename)
    os.execute(string.format('echo "%s" >> %s', line, filename))
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

    describe('buffer_hunks', function()
        local filename = '.gitignore'
        local lines = read_file(filename)

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return only added hunks with correct start and finish', function()
            clear_file_content(filename)
            for i = 1, #lines do
                add_line_to_file(lines[i], filename)
                add_line_to_file('#', filename)
            end
            local error = nil
            local results = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, #lines)
            local counter = 2
            for _, hunk in pairs(results) do
                assert.are.same(hunk.type, 'add')
                assert.are.same(hunk.start, counter)
                assert.are.same(hunk.finish, counter)
                counter = counter + 2
            end
        end)

        it('should return only removed hunks with correct start and finish', function()
            local counter = 0
            clear_file_content(filename)
            for i = 1, #lines do
                if i % 2 == 0 then
                    add_line_to_file(lines[i], filename)
                else
                    counter = counter + 1
                end
            end
            local error = nil
            local results = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, counter)
            for i, hunk in ipairs(results) do
                assert.are.same(hunk.type, 'remove')
                assert.are.same(hunk.start, i - 1)
                assert.are.same(hunk.finish, i - 1)
            end
        end)

        it('should return only changed hunks with correct start and finish', function()
            local counter = 0
            clear_file_content(filename)
            for i = 1, #lines do
                if i % 2 == 0 then
                    add_line_to_file(lines[i], filename)
                else
                    add_line_to_file(lines[i] .. '#########', filename)
                    counter = counter + 1
                end
            end
            local error = nil
            local results = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, counter)
            counter = 1
            for _, hunk in pairs(results) do
                assert.are.same(hunk.type, 'change')
                assert.are.same(hunk.start, counter)
                assert.are.same(hunk.finish, counter)
                counter = counter + 2
            end
        end)

        it('should return all possible hunks with correct start and finish', function()
            clear_file_content(filename)
            for i = 1, #lines do
                -- add
                if i == 1 then
                    add_line_to_file('########', filename)
                    add_line_to_file(lines[i], filename)
                -- change
                elseif i == 2 then
                    add_line_to_file(lines[i] .. '#########', filename)
                -- i == 4 gets removed
                elseif i ~= 4 then
                    add_line_to_file(lines[i], filename)
                end
            end
            local error = nil
            local results = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(#results, 3)
            assert.are.same(results[1].type, 'add')
            assert.are.same(results[2].type, 'change')
            assert.are.same(results[3].type, 'remove')

            for i = 1, #lines do
                -- add
                if i == 1 then
                    local hunk = table.remove(results, 1)
                    assert.are.same(hunk.start, i)
                    assert.are.same(hunk.finish, i)
                -- change
                elseif i == 2 then
                    local hunk = table.remove(results, 1)
                    assert.are.same(hunk.start, i + 1)
                    assert.are.same(hunk.finish, i + 1)
                -- remove
                elseif i == 4 then
                    local hunk = table.remove(results, 1)
                    assert.are.same(hunk.start, i)
                    assert.are.same(hunk.finish, i)
                end
            end
        end)

    end)

    describe('diff', function()
        local filename = '.gitignore'
        local lines = read_file(filename)

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return data table with correct keys', function()
            clear_file_content(filename)
            for i = 1, #lines do
                add_line_to_file(lines[i], filename)
                add_line_to_file('#', filename)
            end
            local error = nil
            local results = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                error = err
                results = hunks
            end)
            job:wait()
            assert.are.same(error, nil)
            assert.are.same(type(results), 'table')

            git.diff(filename, results, function(err, data)
                assert.are.same(err, nil)
                assert.are.same(type(data), 'table')
                local known_imports = {
                    cwd_lines = true,
                    origin_lines = true,
                    lnum_changes = true,
                    file_type = true
                }
                for key, _ in pairs(data) do
                    assert(known_imports[key])
                end
            end)
        end)

        it('should return correct filetype', function()
            clear_file_content(filename)
            for i = 1, #lines do
                add_line_to_file(lines[i], filename)
                add_line_to_file('#', filename)
            end
            local results = nil
            local job = git.buffer_hunks(filename, function(_, hunks)
                results = hunks
            end)
            job:wait()

            git.diff(filename, results, function(_, data)
                assert.are.same(data.file_type, '.gitignore')
            end)
        end)

        it('should have equal number of lines in cwd_lines and orgin_buf for git added file', function()
            clear_file_content(filename)
            for i = 1, #lines do
                add_line_to_file(lines[i], filename)
                add_line_to_file('#', filename)
            end
            local results = nil
            local job = git.buffer_hunks(filename, function(_, hunks)
                results = hunks
            end)
            job:wait()

            git.diff(filename, results, function(_, data)
                assert.are.same(#data.origin_lines, #data.cwd_lines)
                -- os.execute(string.format('echo "%s"', #data.cwd_lines))
            end)
        end)

    end)

end)
