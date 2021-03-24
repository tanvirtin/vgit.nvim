local Hunk = {}
Hunk.__index = Hunk

local function parse_header(line)
    local diffkey = vim.trim(vim.split(line, '@@', true)[2])
    return unpack(vim.tbl_map(function(s)
        return vim.split(string.sub(s, 2), ',')
    end, vim.split(diffkey, ' ')))
end

function Hunk:new(filepath, header)
    local original_state, current_state = parse_header(header)
    local original_state_start = tonumber(original_state[1])
    local original_state_count = tonumber(original_state[2]) or 1
    local current_state_start = tonumber(current_state[1])
    local current_state_count = tonumber(current_state[2]) or 1

    local this = {
        filepath = filepath,
        header = header,
        -- Hunk start and finish should always be relative to the current state.
        start = current_state_start,
        finish = current_state_start + current_state_count - 1,
        type = nil,
        original_state = {
            start = original_state_start,
            count = original_state_count,
        },
        current_state = {
            start = current_state_start,
            count = current_state_count
        },
        diff = {},
    }

    if current_state_count == 0 then
        -- If it's a straight remove with no change, then highlight only one sign column.
        this.finish = current_state_start
        this.type = "remove"
    elseif original_state_count == 0 then
        this.type = "add"
    else
        this.type = "change"
    end

    if this.start < 1 then
        this.start = 1
    end

    if this.finish < 1 then
        this.finish = 1
    end

    if this.start > this.finish then
        this.start = this.finish
    end

    if this.finish < this.start then
        this.finish = this.start
    end

    setmetatable(this, Hunk)
    return this
end

function Hunk:add_line(line)
    table.insert(self.diff, line)
end

return Hunk
