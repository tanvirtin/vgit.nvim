local sign = {
    group = 'git',
    types = {
        add = {
            name = 'GitAdd',
            color = '#d7ffaf',
            text = ' '
        },
        remove = {
            name = 'GitRemove',
            color = '#e95678',
            text = ' '
        },
        change = {
            name = 'GitChange',
            color = '#7AA6DA',
            text = ' '
        },
    },
    priority = 10
}

local function assign_config(config)
    if config and config.colors and config.colors.add then
        sign.types.add.color = config.colors.add
    end
    if config and config.colors and config.colors.remove then
        sign.types.remove.color = config.colors.remove
    end
    if config and config.colors and config.colors.change then
        sign.types.change.color = config.colors.change
    end
end

sign.initialize = function(config)
    assign_config(config)
    for key, type in pairs(sign.types) do
        vim.cmd('hi ' .. sign.types[key].name .. ' guibg=' .. sign.types[key].color)
        vim.fn.sign_define(type.name, {
            text = type.text,
            texthl = type.name
        })
    end
end

sign.clear_all = function()
    vim.schedule(function()
        vim.fn.sign_unplace(sign.group)
    end)
end

sign.place = function(hunk)
    for lnum = hunk.start, hunk.finish do
        vim.schedule(function()
           vim.fn.sign_place(lnum, sign.group, sign.types[hunk.type].name, hunk.filepath, {
               lnum = lnum,
               priority = sign.priority,
           })
        end)
    end
end

return sign
