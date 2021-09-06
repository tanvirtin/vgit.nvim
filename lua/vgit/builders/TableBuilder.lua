local Object = require('plenary.class')
local assert = require('vgit.assertion').assert

local TableBuilder = Object:extend()

function TableBuilder:new(column_labels, rows)
    assert(type(column_labels) == 'table', 'type error :: expected table')
    assert(type(rows) == 'table', 'type error :: expected table')
    return setmetatable({
        spacing = 5,
        column_labels = column_labels,
        rows = rows,
    }, TableBuilder)
end

function TableBuilder:make_paddings()
    local column_labels, rows, spacing = self.column_labels, self.rows, self.spacing
    local padding = {}
    for i = 1, #rows do
        local items = rows[i]
        assert(#column_labels == #items, 'number of columns should be the same as number of column_labels')
        for j = 1, #items do
            local value = items[j]
            if padding[j] then
                padding[j] = math.max(padding[j], #value + spacing)
            else
                padding[j] = spacing + #value + spacing
            end
        end
    end
    return padding
end

function TableBuilder:make_heading(paddings)
    local column_labels, spacing = self.column_labels, self.spacing
    local row = string.format('%s', string.rep(' ', spacing))
    for i = 1, #column_labels do
        local label = column_labels[i]
        row = string.format('%s%s%s', row, label, string.rep(' ', paddings[i] - #label))
    end
    return row
end

function TableBuilder:make(popup)
    local lines = {}
    local rows, spacing = self.rows, self.spacing
    local paddings = self:make_paddings()
    lines[1] = self:make_heading(paddings)
    for i = 1, #rows do
        local row = string.format('%s', string.rep(' ', spacing))
        local items = rows[i]
        for j = 1, #items do
            local value = items[j]
            row = string.format('%s%s%s', row, value, string.rep(' ', paddings[j] - #value))
        end
        lines[#lines + 1] = row
    end
    popup:set_lines(lines)
end

return TableBuilder
