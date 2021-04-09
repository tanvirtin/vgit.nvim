local vim = vim
local unpack = unpack

local Hunk = {}
Hunk.__index = Hunk

local function parse_header(line)
    local diffkey = vim.trim(vim.split(line, '@@', true)[2])
    local original_state, current_state = unpack(
        vim.tbl_map(function(s)
            return vim.split(string.sub(s, 2), ',')
        end,
        vim.split(diffkey, ' '))
    )
    original_state[1] = tonumber(original_state[1])
    original_state[2] = tonumber(original_state[2]) or 1
    current_state[1] = tonumber(current_state[1])
    current_state[2] = tonumber(current_state[2]) or 1
    return original_state, current_state
end

function Hunk:new(filepath, header)
    --[[
        There are two states:
          - original_state (state of file in origin)
          - current_state (state of file in cwd)
        The state is an array which contains two elements:
          - the line index (0 indexed) on which hunk starts
          - total number of lines changed
    --]]
    local original_state, current_state = parse_header(header)

    local this = {
        filepath = filepath,
        -- Hunk start and finish should always be relative to the current state.
        start = current_state[1],
        finish = current_state[1] + current_state[2] - 1,
        type = nil,
        diff = {},
    }

    -- If current state count is 0 and a hunk exists, then lines have been removed.
    if current_state[2] == 0 then
        -- If it's a straight remove with no change, then highlight only one sign column.
        this.start = current_state[1] + 1
        this.finish = current_state[1] + 1
        this.type = 'remove'
    -- If original state count is 0 and current state count is not 0, then lines have been added.
    elseif original_state[2] == 0 then
        this.type = 'add'
    -- When neither state counts are 0, it means some lines have been added and some removed.
    else
        this.type = 'change'
    end

    setmetatable(this, Hunk)
    return this
end

function Hunk:add_line(line)
    table.insert(self.diff, line)
end

return Hunk
