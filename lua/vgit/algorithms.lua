local M = {}

local vim = vim

local function create_hunk(hunks, start, finish, diff, type)
    if type == 'remove' then
        if start < 0 then
            start = 1
        end
        start = start
        finish = start
        table.insert(hunks, {
            start = start,
            finish = finish,
            type = type,
            diff = diff,
        })
    elseif type == 'change' then
        table.insert(hunks, {
            start = start + 1,
            finish = finish,
            type = type,
            diff = diff,
        })
    else
        table.insert(hunks, {
            start = start,
            finish = finish - 1,
            type = type,
            diff = diff,
        })
    end
end

M.myers_difference = function(a_lines, b_lines)
    assert(vim.tbl_islist(a_lines), 'type error :: expected table of type list')
    assert(vim.tbl_islist(b_lines), 'type error :: expected table of type list')
    local history_tracker = { [1] = { x = 0, history = {} } }
    local a_len = #a_lines
    local b_len = #b_lines
    for d = 0, a_len + b_len + 1 do
        for k = -d, d, 2 do
            local x, history
            local go_down = (k == -d or (k ~= d and history_tracker[k - 1].x < history_tracker[k + 1].x))
            if go_down then
                local tracker = history_tracker[k + 1]
                x = tracker.x
                history = tracker.history
            else
                local tracker = history_tracker[k - 1]
                x = tracker.x + 1
                history = tracker.history
            end
            history = vim.tbl_values(history)
            local y = x - k
            if 1 <= y and y <= b_len and go_down then
                table.insert(history, { 1, b_lines[y] })
            elseif 1 <= x and x <= a_len then
                table.insert(history, { -1, a_lines[x] })
            end
            while x < a_len and y < b_len and a_lines[x + 1] == b_lines[y + 1] do
                x = x + 1
                y = y + 1
                table.insert(history, { 0, a_lines[x] })
            end
            if x >= a_len and y >= b_len then
                return history
            else
                history_tracker[k] = { x = x, history = history }
            end
        end
    end
end

M.hunks = function(a_lines, b_lines)
    assert(vim.tbl_islist(a_lines), 'type error :: expected table of type list')
    assert(vim.tbl_islist(b_lines), 'type error :: expected table of type list')
    local diffs = M.myers_difference(a_lines, b_lines)
    local hunks = {}
    local processing_hunk = false
    local predicted_type = nil
    local temp_diff = {}
    local start = 0
    local temp_added_lines = 0
    local temp_removed_lines = 0
    local r_lines = {}
    for line_number, diff in ipairs(diffs) do
        local type = diff[1]
        local line = diff[2]
        if not processing_hunk then
            if type == 1 then
                predicted_type = 'add'
                processing_hunk = true
                table.insert(temp_diff, string.format('+%s', line))
                start = line_number
                temp_added_lines = temp_added_lines + 1
            elseif type == -1 then
                predicted_type = 'undecided'
                processing_hunk = true
                table.insert(temp_diff, string.format('-%s', line))
                table.insert(r_lines, line_number)
                start = line_number
            end
        else
            if type == 1 then
                table.insert(temp_diff, string.format('+%s', line))
                if predicted_type == 'undecided' then
                    predicted_type = 'change'
                end
                temp_added_lines = temp_added_lines + 1
            elseif type == -1 then
                table.insert(temp_diff, string.format('-%s', line))
                table.insert(r_lines, line_number)
                temp_removed_lines = temp_removed_lines + 1
            else
                local removed_lines = 0
                if predicted_type == 'undecided' then
                    predicted_type = 'remove'
                    for _, lnum in ipairs(r_lines) do
                        if line_number > lnum then
                            removed_lines = removed_lines + 1
                        end
                    end
                    removed_lines = removed_lines - temp_removed_lines
                elseif predicted_type == 'change' then
                    for _, lnum in ipairs(r_lines) do
                        if line_number > lnum then
                            removed_lines = removed_lines + 1
                        end
                    end
                    removed_lines = removed_lines - temp_removed_lines
                else
                    removed_lines = #r_lines
                end
                if #temp_diff ~= 0 then
                    -- if the removes appeared before the current line, we can't include the removed lines
                    create_hunk(
                        hunks,
                        start - removed_lines,
                        start - removed_lines + temp_added_lines,
                        temp_diff,
                        predicted_type
                    )
                end
                temp_added_lines = 0
                temp_removed_lines = 0
                processing_hunk = false
                temp_diff = {}
                predicted_type = nil
                start = 0
            end
        end
    end
    if #temp_diff ~= 0 then
        local removed_lines = #r_lines
        if predicted_type == 'undecided' then
            predicted_type = 'remove'
            removed_lines = removed_lines - temp_removed_lines
        end
        create_hunk(
            hunks,
            start - removed_lines,
            start - removed_lines + temp_added_lines,
            temp_diff,
            predicted_type
        )
    end
    return hunks
end

return M
