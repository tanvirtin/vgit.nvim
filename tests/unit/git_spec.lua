local git = require('vgit.git')

local it = it
local vim = vim
local describe = describe
local after_each = after_each
local eq = assert.are.same

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

    describe('constants', function()

        it('should have the correct shape', function()
            eq(git.constants, {
                diff_algorithm = 'histogram',
                empty_tree_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
            })
        end)

    end)

    describe('setup', function()

        it('should store git config as a state', function()
            git.setup()
            local config = git.state:get('config')
            eq(type(config), 'table')
        end)

    end)

    describe('create_hunk', function()
        local headers = {
            add = '@@ -17,0 +18,15 @@ foo bar',
            remove = '@@ -9,9 +8,0 @@ @@ foo bar',
            change = '@@ -10,7 +10,7 @@ foo bar',
            invalid = '@@ --10,-1 +-10,-7 @@ foo bar',
            invalid_zero = '@@ -0,0 +0,0 @@ foo bar',
        }

        it('should store the headers passed in', function()
            for _, value in pairs(headers) do
                local hunk = git.create_hunk(value)
                eq(hunk.header, value)
            end
        end)

        it('should create a hunk from given parameters', function()
            local hunk = git.create_hunk(headers['add'])
            eq(type(hunk), 'table')
            local hunk_keys = { 'header', 'start', 'finish', 'type', 'diff' }
            for key, _ in pairs(hunk) do
                assert(vim.tbl_contains(hunk_keys, key))
            end
        end)

       it('should create a hunk with correct type', function()
            eq(git.create_hunk(headers['add']).type, 'add')
            eq(git.create_hunk(headers['remove']).type, 'remove')
            eq(git.create_hunk(headers['change']).type, 'change')
        end)

       it('should create a hunk with correct start and finish', function()
            local add_hunk = git.create_hunk(headers['add'])
            eq(add_hunk.start, 18)
            eq(add_hunk.finish, 18 + 15 - 1)

            local remove_hunk = git.create_hunk(headers['remove'])
            eq(remove_hunk.start, 8)
            eq(remove_hunk.finish, 8)

            local change_hunk = git.create_hunk(headers['change'])
            eq(change_hunk.start, 10)
            eq(change_hunk.finish, 10 + 7 - 1)
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
                eq(lines[i], line)
            end

            eq(#hunk.diff, #lines)
        end)

    end)

    describe('hunks', function()
        local filename = 'tests/fixtures/simple_file'

        after_each(function()
            reset_head(filename)
        end)

        it('should return only added hunks with correct start and finish', function()
            local lines = add_lines(filename)
            local err, data = git.hunks(filename)
            eq(err, nil)
            eq(#data, #lines)
            local counter = 2
            for _, hunk in pairs(data) do
                eq(hunk.type, 'add')
                eq(hunk.start, counter)
                eq(hunk.finish, counter)
                counter = counter + 2
            end
        end)

        it('should return only removed hunks with correct start and finish', function()
            local _, _, removed_lines = remove_lines(filename)
            local err, data = git.hunks(filename)
            eq(err, nil)
            eq(#data, #removed_lines)
            for i, hunk in ipairs(data) do
                eq(hunk.type, 'remove')
                eq(hunk.start, i - 1)
                eq(hunk.finish, i - 1)
            end
        end)

        it('should return only changed hunks with correct start and finish', function()
            local _, _, changed_lines = change_lines(filename)
            local err, data = git.hunks(filename)
            eq(err, nil)
            eq(#data, #changed_lines)
            local counter = 1
            for _, hunk in pairs(data) do
                eq(hunk.type, 'change')
                eq(hunk.start, counter)
                eq(hunk.finish, counter)
                counter = counter + 2
            end
        end)

        it('should return all possible hunks with correct start and finish', function()
            local lines = augment_file(filename)
            local err, data = git.hunks(filename)
            eq(err, nil)
            eq(#data, 3)
            eq(data[1].type, 'add')
            eq(data[2].type, 'change')
            eq(data[3].type, 'remove')

            for i = 1, #lines do
                -- add
                if i == 1 then
                    local hunk = table.remove(data, 1)
                    eq(hunk.start, i)
                    eq(hunk.finish, i)
                -- change
                elseif i == 2 then
                    local hunk = table.remove(data, 1)
                    eq(hunk.start, i + 1)
                    eq(hunk.finish, i + 1)
                -- remove
                elseif i == 4 then
                    local hunk = table.remove(data, 1)
                    eq(hunk.start, i)
                    eq(hunk.finish, i)
                end
            end
        end)

    end)

    describe('diff', function()
        local filename = 'tests/fixtures/simple_file'

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return data table with correct keys', function()
            local _, lines = add_lines(filename)
            local err, hunks = git.hunks(filename)
            eq(err, nil)
            eq(type(hunks), 'table')
            local diff_err, data = git.diff(lines, hunks)
            eq(diff_err, nil)
            eq(type(data), 'table')
            local expected_keys = {
                current_lines = true,
                previous_lines = true,
                lnum_changes = true,
            }
            for key, _ in pairs(data) do
                assert(expected_keys[key])
            end
            for key, _ in pairs(expected_keys) do
                assert(data[key])
            end
        end)

        it('should have equal number of current_lines and previous_lines for a file with added lines', function()
            local _, lines= add_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            eq(#data.current_lines, #data.previous_lines)
        end)

        it('should have equal number of current_lines and previous_lines for a file with removed lines', function()
            local _, lines = remove_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            eq(#data.current_lines, #data.previous_lines)
        end)

        it('should have equal number of current_lines and previous_lines for a file with changed lines', function()
            local _, lines = change_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            eq(#data.current_lines, #data.previous_lines)
        end)

        it('should have equal number of current_lines and previous_lines for a file with added, removed and changed lines', function()
            local _,lines = augment_file(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            eq(#data.current_lines, #data.previous_lines)
        end)

        it('should have equal number of current_lines and previous_lines for a file with added lines', function()
            local _, lines, added_lines = add_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            local num_added_lines = #added_lines
            assert(#data.current_lines > 0)
            assert(#data.previous_lines > 0)
            eq(#data.current_lines, #data.previous_lines)
            eq(#data.lnum_changes, num_added_lines)
            local counter = 2
            for _, lnum_data in ipairs(data.lnum_changes) do
                eq(lnum_data.lnum, counter)
                eq(lnum_data.type, 'add')
                eq(lnum_data.buftype, 'current')
                counter = counter + 2
            end
        end)

        it('should have correct lnum_changes for a file with removed lines', function()
            local _, lines, removed_lines = remove_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            local num_removed_lines = #removed_lines
            assert(#data.current_lines > 0)
            assert(#data.previous_lines > 0)
            eq(#data.current_lines, #data.previous_lines)
            eq(#data.current_lines, #data.previous_lines)
            eq(#data.lnum_changes, num_removed_lines)
            local counter = 1
            for _, lnum_data in ipairs(data.lnum_changes) do
                eq(lnum_data.lnum, counter)
                eq(lnum_data.type, 'remove')
                eq(lnum_data.buftype, 'previous')
                counter = counter + 2
            end
        end)

        it('should have correct lnum_changes for a file with changed lines', function()
            local _, lines, changed_lines = change_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            local num_changed_lines = #changed_lines
            assert(#data.current_lines > 0)
            assert(#data.previous_lines > 0)
            eq(#data.current_lines, #data.previous_lines)
            eq(#data.current_lines, #data.previous_lines)
            eq(#data.current_lines, #data.previous_lines)
            local counter = 1
            local added_current_lines = 0
            local removed_previous_lines = 0
            for _, lnum_data in ipairs(data.lnum_changes) do
                if lnum_data.buftype == 'previous' and lnum_data.type == 'remove' then
                    eq(lnum_data.lnum, counter)
                    counter = counter + 2
                end
                if lnum_data.buftype == 'current' then
                    assert.are_not.same(lnum_data.type, 'remove')
                    added_current_lines = added_current_lines + 1
                end
            end
            counter = 1
            for _, lnum_data in ipairs(data.lnum_changes) do
                if lnum_data.buftype == 'previous' and lnum_data.type == 'add' then
                    eq(lnum_data.lnum, counter)
                    counter = counter + 2
                end
                if lnum_data.buftype == 'previous' then
                    assert.are_not.same(lnum_data.type, 'added')
                    removed_previous_lines = removed_previous_lines + 1
                end
            end
            eq(num_changed_lines, added_current_lines)
            eq(num_changed_lines, removed_previous_lines)
        end)

        it('should have correct lnum_changes for a file with added, removed and changed lines', function()
            local _, lines, added_lines, removed_lines, changed_lines = augment_file(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(lines, hunks)
            local num_added_lines = #added_lines
            local num_removed_lines = #removed_lines
            local num_changed_lines = #changed_lines
            assert(#data.current_lines > 0)
            assert(#data.previous_lines > 0)
            eq(#data.current_lines, #data.previous_lines)
            eq(#data.current_lines, #data.previous_lines)
            eq(#data.current_lines, #data.previous_lines)
            local added_current_lines = 0
            local removed_previous_lines = 0
            local counter = 1
            for _, lnum_data in ipairs(data.lnum_changes) do
                if lnum_data.buftype == 'current' and lnum_data.type == 'add' then
                    eq(lnum_data.lnum, counter)
                    counter = counter + 2
                end
                if lnum_data.buftype == 'current' then
                    assert.are_not.same(lnum_data.type, 'remove')
                    added_current_lines = added_current_lines + 1
                end
            end
            counter = 5
            local first = false
            for _, lnum_data in ipairs(data.lnum_changes) do
                if lnum_data.buftype == 'previous' and lnum_data.type == 'remove' then
                    if not first then
                        eq(lnum_data.lnum, 3)
                    else
                        eq(lnum_data.lnum, counter)
                        counter = counter + 1
                    end
                    first = true
                end
                if lnum_data.buftype == 'previous' then
                    assert.are_not.same(lnum_data.type, 'added')
                    removed_previous_lines = removed_previous_lines + 1
                end
            end
            eq(added_current_lines, num_added_lines + num_changed_lines)
            eq(removed_previous_lines, num_removed_lines + num_changed_lines)
        end)

        it('should have correct current_lines and previous_lines for added lines', function()
            local lines, new_lines, added_lines = add_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(new_lines, hunks)
            local current_lines = data.current_lines
            local previous_lines = data.previous_lines
            for _, index in ipairs(added_lines) do
                eq(current_lines[index], new_lines[index])
                assert.are_not.same(current_lines[index], lines[index])
                eq(previous_lines[index], '')
            end
        end)

        it('should have correct current_lines and previous_lines for removed lines', function()
            local lines, new_lines, removed_lines = remove_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(new_lines, hunks)
            local current_lines = data.current_lines
            local previous_lines = data.previous_lines
            for _, index in ipairs(removed_lines) do
                eq(current_lines[index], new_lines[index])
                assert.are_not.same(current_lines[index], lines[index])
                assert.are_not.same(previous_lines[index], new_lines[index])
                eq(new_lines[index], '')
            end
        end)

        it('should have correct current_lines and previous_lines for changed lines', function()
            local _, new_lines, changed_lines = add_lines(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(new_lines, hunks)
            local current_lines = data.current_lines
            local previous_lines = data.previous_lines
            for _, index in ipairs(changed_lines) do
                eq(current_lines[index], new_lines[index])
                assert.are_not.same(current_lines[index], previous_lines[index])
            end
        end)

        it('should have correct current_lines and previous_lines for added, removed and changed lines', function()
            local _, new_lines, added_lines, removed_lines, changed_lines = augment_file(filename)
            local _, hunks = git.hunks(filename)
            local _, data = git.diff(new_lines, hunks)
            local current_lines = data.current_lines
            for _, index in ipairs(added_lines) do
                eq(current_lines[index], new_lines[index])
            end
            for _, index in ipairs(removed_lines) do
                eq(current_lines[index], new_lines[index])
            end
            for _, index in ipairs(changed_lines) do
                eq(current_lines[index], new_lines[index])
            end
        end)

    end)

    describe('reset', function()
        local filename = 'tests/fixtures/simple_file'

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should reset a file with only added lines', function()
            local lines = add_lines(filename)
            local new_lines = read_file(filename)
            assert.are_not.same(#lines, #new_lines)
            local err = git.reset(filename)
            eq(err, nil)
            local lines_after_reset = read_file(filename)
            for index, line in ipairs(lines_after_reset) do
                local previousal_line = lines[index]
                eq(line, previousal_line)
            end
        end)

        it('should reset a file with only removed lines', function()
            local lines = remove_lines(filename)
            local new_lines = read_file(filename)
            assert.are_not.same(#lines, #new_lines)
            local err = git.reset(filename)
            eq(err, nil)
            local lines_after_reset = read_file(filename)
            for index, line in ipairs(lines_after_reset) do
                local previousal_line = lines[index]
                eq(line, previousal_line)
            end
        end)

        it('should reset a file with only changed lines', function()
            local lines = change_lines(filename)
            local err = git.reset(filename)
            eq(err, nil)
            local lines_after_reset = read_file(filename)
            for index, line in ipairs(lines_after_reset) do
                local previousal_line = lines[index]
                eq(line, previousal_line)
            end
        end)

        it('should reset a file with added, removed, changed lines', function()
            local lines = augment_file(filename)
            local new_lines = read_file(filename)
            assert.are_not.same(#lines, #new_lines)
            local err = git.reset(filename)
            eq(err, nil)
            local lines_after_reset = read_file(filename)
            for index, line in ipairs(lines_after_reset) do
                local previousal_line = lines[index]
                eq(line, previousal_line)
            end
        end)

    end)

    describe('config', function()

        it('should return a table', function()
            local err, config = git.config()
            eq(err, nil)
            eq(type(config), 'table')
        end)

        it('should contain necessary git config information equivalent to what you see in "git config --list"', function()
            local err, config = git.config()
            eq(err, nil)
            eq(type(config), 'table')
        end)

    end)

    describe('create_blame', function()
        local committed_info = {
            'e71cf398fdbe7f13560d65b72d6ec111c4c2c837 131 183',
            'author tanvirtin',
            'author-mail <tinman@tinman.com>',
            'author-time 1620254313',
            'author-tz -0400',
            'committer tanvirtin',
            'committer-mail <tinman@tinman.com>',
            'committer-time 1620254313',
            'committer-tz -0400',
            'summary blame is now parsed and shown as a virtual text',
            'previous bc019ecab452195b1d044998efb7994a6467cca7 lua/git/git.lua',
            'filename lua/git/git.lua',
        }
        local uncommitted_info = {
            '0000000000000000000000000000000000000000 94 94',
            'author Not Committed Yet',
            'author-mail <not.committed.yet>',
            'author-time 1620420779',
            'author-tz -0400',
            'committer Not Committed Yet',
            "committer-mail <not.committed.yet>",
            "committer-time 1620420779",
            "committer-tz -0400",
            "summary Version of README.md from README.md",
            "previous a08d97a4bd97574460f33fc1b9e645bfa9d2f703 README.md",
            "filename README.md"
        }

        it('should create a committed blame with proper information populated', function()
            local blame = git.create_blame(committed_info)
            eq(blame, {
                lnum = 183,
                commit_hash = 'e71cf398fdbe7f13560d65b72d6ec111c4c2c837',
                parent_hash = 'bc019ecab452195b1d044998efb7994a6467cca7',
                author = 'tanvirtin',
                author_mail = 'tinman@tinman.com',
                author_time = 1620254313,
                author_tz = '-0400',
                committer = 'tanvirtin',
                committer_mail = 'tinman@tinman.com',
                committer_time = 1620254313,
                committer_tz = '-0400',
                commit_message = 'blame is now parsed and shown as a virtual text',
                committed = true,
            })
        end)

        it('should create a uncommitted blame with proper information populated', function()
            local blame = git.create_blame(uncommitted_info)
            eq(blame, {
                lnum = 94,
                commit_hash = '0000000000000000000000000000000000000000',
                parent_hash = 'a08d97a4bd97574460f33fc1b9e645bfa9d2f703',
                author = 'Not Committed Yet',
                author_mail = 'not.committed.yet',
                author_time = 1620420779,
                author_tz = '-0400',
                committer = 'Not Committed Yet',
                committer_mail = 'not.committed.yet',
                committer_time = 1620420779,
                committer_tz = '-0400',
                commit_message = 'Version of README.md from README.md',
                committed = false,

            })
        end)

    end)

    describe('blames', function()
        local filename = 'tests/fixtures/simple_file'

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return array with blames same size as the number of lines in the file', function()
            local lines = read_file(filename)
            local err, blames = git.blames(filename)
            eq(err, nil)
            eq(#blames, #lines)
        end)

        it('should return array with only commited blames', function()
            local err, blames = git.blames(filename)
            eq(err, nil)
            for _, blame in ipairs(blames) do
                eq(blame.committed, true)
            end
        end)

        it('should return uncommitted blames for lines which has been added', function()
            local _, _, added_line_indices = add_lines(filename)
            local err, blames = git.blames(filename)
            eq(err, nil)
            local index_map = {}
            for _, index in ipairs(added_line_indices) do
                eq(blames[index].committed, false)
                index_map[tostring(index)] = true
            end
            for index, blame in ipairs(blames) do
                if not index_map[tostring(index)] then
                    eq(blame.committed, true)
                end
            end
        end)

    end)

    describe('current_file_changes', function()
        local filename = 'tests/fixtures/simple_file'

        after_each(function()
            os.execute(string.format('git checkout HEAD -- %s', filename))
        end)

        it('should return the correct number of filenames when there are changes in the repository', function()
            add_lines(filename)
            local err, filenames = git.current_file_changes();
            eq(err, nil)
            eq(true, vim.tbl_contains(filenames, filename))
        end)

    end)

    describe('show', function()
        local filename = 'tests/fixtures/simple_file'

        it('should retrieve the contents of the current file with a given filename', function()
            local err, data = git.show(filename)
            local lines = read_file(filename)
            eq(err, nil)
            eq(data, lines)
        end)

    end)

    describe('create_log', function()
        local raw_log = '"1ee1810cd9baee8cf5d750e9c1398f058fd39d5d-e2f47d90fbffc15b95c015e140d8bfb600d49904-1618464789-tanvirtin-tanvir.tinz@gmail.com-fix fixture"'

        it('should create a log object from a given raw log entry', function()
            local log = git.create_log(raw_log)
            eq(log, {
                author_email = 'tanvir.tinz@gmail.com',
                author_name = 'tanvirtin',
                commit_hash = '1ee1810cd9baee8cf5d750e9c1398f058fd39d5d',
                parent_hash = 'e2f47d90fbffc15b95c015e140d8bfb600d49904',
                summary = 'fix fixture',
                timestamp = '1618464789',
            })
        end)

    end)

    describe('logs', function()
        local filename = 'tests/fixtures/simple_file'

        it('should always have an initial entry indicating the current head', function()
            local err, logs = git.logs(filename)
            eq(err, nil)
            local head_log = logs[1]
            assert.are_not.same(head_log, nil)
        end)

    end)

    describe('is_inside_work_tree', function()

        it('should return true if user is currently inside a git tree', function()
            assert(git.is_inside_work_tree())
        end)

    end)

    describe('ls_tracked', function()

        it('should return all files associated with the project', function()
            local err, files = git.ls_tracked()
            eq(err, nil)
            eq(files, {
                '.github/ISSUE_TEMPLATE/bug_report.md',
                '.github/ISSUE_TEMPLATE/feature_request.md',
                '.github/workflows/ci.yml',
                '.gitignore',
                '.luacheckrc',
                'LICENSE',
                'Makefile',
                'README.md',
                'lua/vgit/Bstate.lua',
                'lua/vgit/State.lua',
                'lua/vgit/border.lua',
                'lua/vgit/buffer.lua',
                'lua/vgit/defer.lua',
                'lua/vgit/fs.lua',
                'lua/vgit/git.lua',
                'lua/vgit/highlighter.lua',
                'lua/vgit/init.lua',
                'lua/vgit/ui.lua',
                'lua/vgit/view.lua',
                'lua/vgit/widget.lua',
                'tests/fixtures/simple_file',
                'tests/unit/Bstate_spec.lua',
                'tests/unit/State_spec.lua',
                'tests/unit/defer_spec.lua',
                'tests/unit/fs_spec.lua',
                'tests/unit/git_spec.lua',
                'tests/unit/highlighter_spec.lua',
                'tests/unit/init_spec.lua',
            })
        end)

    end)

end)
