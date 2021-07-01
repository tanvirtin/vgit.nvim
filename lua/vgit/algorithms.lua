local M = {}

local function create_hunk(hunks, start, finish, diff, type)
    if type == 'remove' then
        if start < 0 then
            start = 0
        end
        hunks[#hunks + 1] = {
            start = start,
            finish = start,
            type = type,
            diff = diff,
        }
    elseif type == 'change' then
        local hunk = {
            start = start + 1,
            finish = finish,
            type = type,
            diff = diff,
        }
        hunks[#hunks + 1] = hunk
        if hunk.start < 1 then
            hunk.start = 1
            hunk.finish = 1
        end
    else
        hunks[#hunks + 1] = {
            start = start,
            finish = finish - 1,
            type = type,
            diff = diff,
        }
    end
end

M.myers_difference = function(a_lines, b_lines)
    local steps = { [1] = { x = 0, history = {} } }
    local a_len = #a_lines
    local b_len = #b_lines
    local max = a_len + b_len + 1
    for d = 0, max do
        for k = -d, d, 2 do
            local x, history
            local go_down = (k == -d or (k ~= d and steps[k - 1].x < steps[k + 1].x))
            if go_down then
                local step = steps[k + 1]
                x = step.x
                history = step.history
            else
                local step = steps[k - 1]
                x = step.x + 1
                history = step.history
            end
            local temp_history = history
            history = {}
            for i = 1, #temp_history do
                history[i] = temp_history[i]
            end
            local y = x - k
            if 1 <= y and y <= b_len and go_down then
                history[#history + 1] = { 1, b_lines[y] }
            elseif 1 <= x and x <= a_len then
                history[#history + 1] = { -1, a_lines[x] }
            end
            while x < a_len and y < b_len and a_lines[x + 1] == b_lines[y + 1] do
                x = x + 1
                y = y + 1
                history[#history + 1] = { 0, a_lines[x] }
            end
            if x >= a_len and y >= b_len then
                return history
            else
                steps[k] = { x = x, history = history }
            end
        end
    end
end

M.hunks = function(a_lines, b_lines)
    local diffs = M.myers_difference(a_lines, b_lines)
    local hunks = {}
    local processing_hunk = false
    local predicted_type = nil
    local temp_diff = {}
    local start = 0
    local temp_added_lines = 0
    local temp_removed_lines = 0
    local r_lines = {}
    for line_number = 1, #diffs do
        local diff = diffs[line_number]
        local type = diff[1]
        local line = diff[2]
        if not processing_hunk then
            if type == 1 then
                predicted_type = 'add'
                processing_hunk = true
                temp_diff[#temp_diff + 1] = string.format('+%s', line)
                start = line_number
                temp_added_lines = temp_added_lines + 1
            elseif type == -1 then
                predicted_type = 'undecided'
                processing_hunk = true
                temp_diff[#temp_diff + 1] = string.format('-%s', line)
                r_lines[#r_lines + 1] = line_number
                start = line_number
            end
        else
            if type == 1 then
                temp_diff[#temp_diff + 1] = string.format('+%s', line)
                if predicted_type == 'undecided' then
                    predicted_type = 'change'
                end
                temp_added_lines = temp_added_lines + 1
            elseif type == -1 then
                temp_diff[#temp_diff + 1] = string.format('-%s', line)
                r_lines[#r_lines + 1] = line_number
                temp_removed_lines = temp_removed_lines + 1
            else
                local removed_lines = 0
                if predicted_type == 'undecided' then
                    predicted_type = 'remove'
                    for i = 1, #r_lines do
                        local lnum = r_lines[i]
                        if line_number > lnum then
                            removed_lines = removed_lines + 1
                        end
                    end
                    removed_lines = removed_lines - temp_removed_lines
                elseif predicted_type == 'change' then
                    for i = 1, #r_lines do
                        local lnum = r_lines[i]
                        if line_number > lnum then
                            removed_lines = removed_lines + 1
                        end
                    end
                    removed_lines = removed_lines - temp_removed_lines
                else
                    removed_lines = #r_lines
                end
                if #temp_diff ~= 0 then
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
