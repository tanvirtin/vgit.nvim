local Hunk = {}
Hunk.__index = Hunk

local function parse_diff_header(line)
    local diffkey = vim.trim(vim.split(line, '@@', true)[2])
    return unpack(vim.tbl_map(function(s)
        return vim.split(string.sub(s, 2), ',')
    end, vim.split(diffkey, ' ')))
end

function Hunk:new(filepath, header)
    local original_state, new_state = parse_diff_header(header)
    local original_state_start = tonumber(original_state[1])
    local original_state_count = tonumber(original_state[2]) or 1
    local new_state_start = tonumber(new_state[1])
    local new_state_count = tonumber(new_state[2]) or 1

    local this = {
        filepath = filepath,
        header = header,
        -- Hunk start and finish should always be relative to the current state.
        start = new_state_start,
        finish = new_state_start + new_state_count - 1,
        type = nil,
        original_state = {
            start = original_state_start,
            count = original_state_count,
        },
        new_state = {
            start = new_state_start,
            count = new_state_count
        },
        diff = {},
    }

    if new_state_count == 0 then
        -- If it's a straight remove with no change, then highlight only one sign column.
        this.finish = new_state_start
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

    setmetatable(this, Hunk)
    return this
end

function Hunk:add_diff(line)
    table.insert(self.diff, line)
end

function Hunk:tostring()
    local str = ''
    str = str .. 'filepath: ' .. self.filepath .. '\n'
    str = str .. 'header: ' .. self.header .. '\n'
    str = str .. 'start: ' .. self.start .. '\n'
    str = str .. 'finish: ' .. self.finish .. '\n'
    str = str .. 'type: ' .. self.type .. '\n'
    str = str .. 'original_state.start: ' .. self.original_state.start .. '\n'
    str = str .. 'original_state.count: ' .. self.original_state.count .. '\n'
    str = str .. 'new_state.start: ' .. self.new_state.start .. '\n'
    str = str .. 'new_state.count: ' .. self.new_state.count .. '\n'
    str = str .. 'diff:\n'
    for _, line in ipairs(self.diff) do
        str = str .. '  ' .. line .. '\n'
    end
    str = str .. '\n\n'
    return str
end

return Hunk
