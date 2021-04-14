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
    local added_lines = {}
    clear_file_content(filename)
    local add_count = 1
    for i = 1, #lines do
        add_line_to_file(lines[i], filename)
        add_line_to_file('#', filename)
        table.insert(added_lines, i + add_count)
        add_count = add_count + 1
    end
    return lines, read_file(filename), added_lines
end

local function remove_lines(filename)
    local lines = read_file(filename)
    local new_lines = {}
    local removed_lines = {}
    clear_file_content(filename)
    for i = 1, #lines do
        if i % 2 == 0 then
            add_line_to_file(lines[i], filename)
            table.insert(new_lines, lines[i])
        else
            table.insert(new_lines, '')
            table.insert(removed_lines, i)
        end
    end
    return lines, new_lines, removed_lines
end

local function change_lines(filename)
    local lines = read_file(filename)
    local changed_lines = {}
    clear_file_content(filename)
    for i = 1, #lines do
        if i % 2 == 0 then
            add_line_to_file(lines[i], filename)
        else
            add_line_to_file(lines[i] .. '#', filename)
            table.insert(changed_lines, i)
        end
    end
    return lines, read_file(filename), changed_lines
end

local function augment_file(filename)
    local lines = read_file(filename)
    local new_lines = {}
    local added_lines = {}
    local removed_lines = {}
    local changed_lines = {}
    clear_file_content(filename)
    local add_count = 1
    for i = 1, #lines do
        -- add
        if i == 1 then
            add_line_to_file('#', filename)
            add_line_to_file(lines[i], filename)
            table.insert(added_lines, i + add_count)
            table.insert(new_lines, '#')
            table.insert(new_lines, lines[i])
            add_count = add_count + 1
        -- change
        elseif i == 2 then
            add_line_to_file(lines[i] .. '#', filename)
            table.insert(new_lines, lines[i] .. '#')
            table.insert(changed_lines, i)
        elseif i == 3 then
            add_line_to_file(lines[i], filename)
            table.insert(new_lines, lines[i])
        -- anything else gets removed
        else
            table.insert(new_lines, '')
            table.insert(removed_lines, i)
        end
    end
    return lines, new_lines, added_lines, removed_lines, changed_lines
end

local function reset_head(filename)
    os.execute(string.format('git checkout HEAD -- %s', filename))
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
        local filename = 'tests/fixture/simple_file'

        after_each(function()
            reset_head(filename)
        end)

        it('should return only added hunks with correct start and finish', function()
            local lines = add_lines(filename)
            local err, data = git.buffer_hunks(filename)
            assert.are.same(err, nil)
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
            local _, _, removed_lines = remove_lines(filename)
            local err, data = git.buffer_hunks(filename)
            assert.are.same(err, nil)
            assert.are.same(#data, #removed_lines)
            for i, hunk in ipairs(data) do
                assert.are.same(hunk.type, 'remove')
                assert.are.same(hunk.start, i - 1)
                assert.are.same(hunk.finish, i - 1)
            end
        end)

        it('should return only changed hunks with correct start and finish', function()
            local _, _, changed_lines = change_lines(filename)
            local err, data = git.buffer_hunks(filename)
            assert.are.same(err, nil)
            assert.are.same(#data, #changed_lines)
            local counter = 1
            for _, hunk in pairs(data) do
                assert.are.same(hunk.type, 'change')
                assert.are.same(hunk.start, counter)
                assert.are.same(hunk.finish, counter)
                counter = counter + 2
            end
        end)

        it('should return all possible hunks with correct start and finish', function()
            local lines = augment_file(filename)
            local err, data = git.buffer_hunks(filename)
            assert.are.same(err, nil)
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
        local filename = 'tests/fixture/simple_file'

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return data table with correct keys', function()
            add_lines(filename)
            local err, hunks = git.buffer_hunks(filename)
            assert.are.same(err, nil)
            assert.are.same(type(hunks), 'table')
            local diff_err, data = git.buffer_diff(filename, hunks)
            assert.are.same(diff_err, nil)
            assert.are.same(type(data), 'table')
            local expected_keys = {
                cwd_lines = true,
                origin_lines = true,
                lnum_changes = true,
            }
            for key, _ in pairs(data) do
                assert(expected_keys[key])
            end
            for key, _ in pairs(expected_keys) do
                assert(data[key])
            end
        end)

        it('should have equal number of cwd_lines and origin_lines for a file with added lines', function()
            add_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
        end)

        it('should have equal number of cwd_lines and origin_lines for a file with removed lines', function()
            remove_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
        end)

        it('should have equal number of cwd_lines and origin_lines for a file with changed lines', function()
            change_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
        end)

        it('should have equal number of cwd_lines and origin_lines for a file with added, removed and changed lines', function()
            augment_file(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
        end)

        it('should have equal number of cwd_lines and origin_lines for a file with added lines', function()
            local _, _, added_lines = add_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local num_added_lines = #added_lines
            assert(#data.cwd_lines > 0)
            assert(#data.origin_lines > 0)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.lnum_changes.cwd.added, num_added_lines)
            assert.are.same(#data.lnum_changes.cwd.removed, 0)
            assert.are.same(#data.lnum_changes.origin.added, 0)
            assert.are.same(#data.lnum_changes.origin.removed, 0)
            local counter = 2
            for _, value in ipairs(data.lnum_changes.cwd.added) do
                assert.are.same(value, counter)
                counter = counter + 2
            end
        end)

        it('should have correct lnum_changes for a file with removed lines', function()
            local _, _, removed_lines = remove_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local num_removed_lines = #removed_lines
            assert(#data.cwd_lines > 0)
            assert(#data.origin_lines > 0)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.lnum_changes.cwd.removed, 0)
            assert.are.same(#data.lnum_changes.cwd.added, 0)
            assert.are.same(#data.lnum_changes.origin.added, 0)
            assert.are.same(#data.lnum_changes.origin.removed, num_removed_lines)
            local counter = 1
            for _, value in ipairs(data.lnum_changes.origin.removed) do
                assert.are.same(value, counter)
                counter = counter + 2
            end
        end)

        it('should have correct lnum_changes for a file with changed lines', function()
            local _, _, changed_lines = change_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local num_changed_lines = #changed_lines
            assert(#data.cwd_lines > 0)
            assert(#data.origin_lines > 0)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.lnum_changes.cwd.removed, 0)
            assert.are.same(#data.lnum_changes.cwd.added, num_changed_lines)
            assert.are.same(#data.lnum_changes.origin.added, 0)
            assert.are.same(#data.lnum_changes.origin.removed, num_changed_lines)
            local counter = 1
            for _, value in ipairs(data.lnum_changes.origin.removed) do
                assert.are.same(value, counter)
                counter = counter + 2
            end
            counter = 1
            for _, value in ipairs(data.lnum_changes.origin.added) do
                assert.are.same(value, counter)
                counter = counter + 2
            end
        end)

        it('should have correct lnum_changes for a file with added, removed and changed lines', function()
            local _, _, added_lines, removed_lines, changed_lines = augment_file(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local num_added_lines = #added_lines
            local num_removed_lines = #removed_lines
            local num_changed_lines = #changed_lines
            assert(#data.cwd_lines > 0)
            assert(#data.origin_lines > 0)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.cwd_lines, #data.origin_lines)
            assert.are.same(#data.lnum_changes.cwd.removed, 0)
            assert.are.same(#data.lnum_changes.cwd.added, num_added_lines + num_changed_lines)
            assert.are.same(#data.lnum_changes.origin.added, 0)
            assert.are.same(#data.lnum_changes.origin.removed, num_removed_lines + num_changed_lines)
            local counter = 1
            for _, value in ipairs(data.lnum_changes.cwd.added) do
                assert.are.same(value, counter)
                counter = counter + 2
            end
            counter = 5
            for index, value in ipairs(data.lnum_changes.origin.removed) do
                if index == 1 then
                    assert.are.same(value, 3)
                else
                    assert.are.same(value, counter)
                    counter = counter + 1
                end
            end
        end)

        it('should have correct cwd_lines and origin_lines for added lines', function()
            local lines, new_lines, added_lines = add_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local cwd_lines = data.cwd_lines
            local origin_lines = data.origin_lines
            for _, index in ipairs(added_lines) do
                assert.are.same(cwd_lines[index], new_lines[index])
                assert.are_not.same(cwd_lines[index], lines[index])
                assert.are.same(origin_lines[index], '')
            end
        end)

        it('should have correct cwd_lines and origin_lines for removed lines', function()
            local lines, new_lines, removed_lines = remove_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local cwd_lines = data.cwd_lines
            local origin_lines = data.origin_lines
            for _, index in ipairs(removed_lines) do
                assert.are.same(cwd_lines[index], new_lines[index])
                assert.are_not.same(cwd_lines[index], lines[index])
                assert.are_not.same(origin_lines[index], new_lines[index])
                assert.are.same(new_lines[index], '')
            end
        end)

        it('should have correct cwd_lines and origin_lines for changed lines', function()
            local _, new_lines, changed_lines = add_lines(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local cwd_lines = data.cwd_lines
            local origin_lines = data.origin_lines
            for _, index in ipairs(changed_lines) do
                assert.are.same(cwd_lines[index], new_lines[index])
                assert.are_not.same(cwd_lines[index], origin_lines[index])
            end
        end)

        it('should have correct cwd_lines and origin_lines for added, removed and changed lines', function()
            local _, new_lines, added_lines, removed_lines, changed_lines = augment_file(filename)
            local _, hunks = git.buffer_hunks(filename)
            local _, data = git.buffer_diff(filename, hunks)
            local cwd_lines = data.cwd_lines
            for _, index in ipairs(added_lines) do
                assert.are.same(cwd_lines[index], new_lines[index])
            end
            for _, index in ipairs(removed_lines) do
                assert.are.same(cwd_lines[index], new_lines[index])
            end
            for _, index in ipairs(changed_lines) do
                assert.are.same(cwd_lines[index], new_lines[index])
            end
        end)

    end)

end)
