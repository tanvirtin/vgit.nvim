local buffer = require('vgit.buffer')

local vim = vim

local Widget = {}
Widget.__index = Widget

local function global_width()
    return vim.o.columns
end

local function global_height()
    return vim.o.lines
end

local function new(views, close_mappings, actions)
    assert(type(views) == 'table', 'Invalid options provided for Widget')
    return setmetatable({
        views = views,
        actions = actions,
        close_mappings = close_mappings,
        internals = { rendered = false }
    }, Widget)
end

function Widget:views()
    return self.views
end

function Widget:render()
    if self.internals.rendered then
        return
    end
    for _, v in ipairs(self.views) do
        v:render()
    end
    local all_wins = {}
    for _, v in ipairs(self.views) do
        table.insert(all_wins, v:get_win_id())
        table.insert(all_wins, v:get_border_win_id())
    end
    for _, v in ipairs(self.views) do
        local buf = v:get_buf()
        buffer.add_autocmd(
            buf,
            'BufWinLeave',
            string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(all_wins))
        )
        if self.actions then
            for _, action in ipairs(self.actions) do
                buffer.add_keymap(
                    buf,
                    action.mapping,
                    (type(action.action) == 'function' and action.action(v)) or action.action
                )
            end
        end
    end
    if self.close_mappings then
        for _, mapping in ipairs(self.close_mappings) do
            for _, v in ipairs(self.views) do
                local buf = v:get_buf()
                buffer.add_keymap(
                    buf,
                    mapping,
                    string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(all_wins))
                )
            end
        end
    end
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
        local is_buf_listed = vim.api.nvim_buf_get_option(buf, 'buflisted') == true
        if is_buf_listed then
            if buffer.is_valid(buf) then
                buffer.add_autocmd(
                    buf,
                    'BufEnter',
                    string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(all_wins))
                )
            end
        end
    end
    self.internals.rendered = true
end

return {
    new = new,
    global_height = global_height,
    global_width = global_width,
    __object = Widget,
}
