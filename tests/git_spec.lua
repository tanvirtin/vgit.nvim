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

local function add_lines(filename)
    local lines = read_file(filename)
    local added_lines = 0
    clear_file_content(filename)
    for i = 1, #lines do
        add_line_to_file(lines[i], filename)
        add_line_to_file('#', filename)
        added_lines = added_lines + 1
    end
    return lines, added_lines
end

local function remove_lines(filename)
    local lines = read_file(filename)
    local removed_lines = 0
    clear_file_content(filename)
    for i = 1, #lines do
        if i % 2 == 0 then
            add_line_to_file(lines[i], filename)
        else
            removed_lines = removed_lines + 1
        end
    end
    return lines, removed_lines
end

local function change_lines(filename)
    local lines = read_file(filename)
    local changed_lines = 0
    clear_file_content(filename)
    for i = 1, #lines do
        if i % 2 == 0 then
            add_line_to_file(lines[i], filename)
        else
            add_line_to_file(lines[i] .. '#########', filename)
            changed_lines = changed_lines + 1
        end
    end
    return lines, changed_lines
end

local function augment_file(filename)
    local lines = read_file(filename)
    local added_lines = 0
    local removed_lines = 0
    local changed_lines = 0
    local altered_lines = 0
    clear_file_content(filename)
    for i = 1, #lines do
        -- add
        if i == 1 then
            add_line_to_file('########', filename)
            add_line_to_file(lines[i], filename)
            added_lines = added_lines + 1
        -- change
        elseif i == 2 then
            add_line_to_file(lines[i] .. '#########', filename)
            changed_lines = changed_lines + 1
        -- i == 4 gets removed
        elseif i == 4 then
            add_line_to_file(lines[i], filename)
            removed_lines = removed_lines + 1
        else
            altered_lines = altered_lines + 1
        end
    end
    return lines, added_lines, removed_lines, changed_lines, altered_lines
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

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return only added hunks with correct start and finish', function()
            local lines = add_lines(filename)
            local err_result = nil
            local data = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                err_result = err
                data = hunks
            end)
            job:wait()
            assert.are.same(err_result, nil)
            assert.are.same(#data, #lines)
            local counter = 2
            for _, hunk in pairs(data) do
                assert.are.same(hunk.type, 'add')
                assert.are.same(hunk.start, counter)
                assert.are.same(hunk.finish, counter)
                counter = counter + 2
            end
        end)

        it('should return only removed hunks with correct start and finish', function()
            local _, counter = remove_lines(filename)
            local err_result = nil
            local data = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                err_result = err
                data = hunks
            end)
            job:wait()
            assert.are.same(err_result, nil)
            assert.are.same(#data, counter)
            for i, hunk in ipairs(data) do
                assert.are.same(hunk.type, 'remove')
                assert.are.same(hunk.start, i - 1)
                assert.are.same(hunk.finish, i - 1)
            end
        end)

        it('should return only changed hunks with correct start and finish', function()
            local _, counter = change_lines(filename)
            local err_result = nil
            local data = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                err_result = err
                data = hunks
            end)
            job:wait()
            assert.are.same(err_result, nil)
            assert.are.same(#data, counter)
            counter = 1
            for _, hunk in pairs(data) do
                assert.are.same(hunk.type, 'change')
                assert.are.same(hunk.start, counter)
                assert.are.same(hunk.finish, counter)
                counter = counter + 2
            end
        end)

        it('should return all possible hunks with correct start and finish', function()
            local lines = augment_file(filename)
            local err_result = nil
            local data = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                err_result = err
                data = hunks
            end)
            job:wait()
            assert.are.same(err_result, nil)
            assert.are.same(#data, 3)
            assert.are.same(data[1].type, 'add')
            assert.are.same(data[2].type, 'change')
            assert.are.same(data[3].type, 'remove')

            for i = 1, #lines do
                -- add
                if i == 1 then
                    local hunk = table.remove(data, 1)
                    assert.are.same(hunk.start, i)
                    assert.are.same(hunk.finish, i)
                -- change
                elseif i == 2 then
                    local hunk = table.remove(data, 1)
                    assert.are.same(hunk.start, i + 1)
                    assert.are.same(hunk.finish, i + 1)
                -- remove
                elseif i == 4 then
                    local hunk = table.remove(data, 1)
                    assert.are.same(hunk.start, i)
                    assert.are.same(hunk.finish, i)
                end
            end
        end)

    end)

    describe('diff', function()
        local filename = '.gitignore'

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return data table with correct keys', function()
            add_lines(filename)
            local err_result = nil
            local data = nil
            local job = git.buffer_hunks(filename, function(err, hunks)
                err_result = err
                data = hunks
            end)
            job:wait()
            assert.are.same(err_result, nil)
            assert.are.same(type(data), 'table')
            err_result = nil
            data = nil
            job = git.diff(filename, data, function(err, diff)
                err_result = err
                data = diff
                os.execute(string.format('echo "%s"', vim.inspect(vim.tbl_keys(diff))))
            end)
            job:wait()
            assert.are.same(err_result, nil)
            assert.are.same(type(data), 'table')
            local expected_keys = {
                cwd_lines = true,
                origin_lines = true,
                lnum_changes = true,
                file_type = true
            }
            for key, _ in pairs(data) do
                assert(expected_keys[key])
            end
        end)

    end)

end)
