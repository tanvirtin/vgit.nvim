local sign = {
    group = 'git',
    types = {
        add = {
            name = 'gitadd',
            text = '+'
        },
        remove = {
            name = 'gitremove',
            text = '-'
        },
        change = {
            name = 'gitchange',
            text = '~'
        },
    },
    priority = 7
}

sign.initialize = function()
    for _, type in pairs(sign.types) do
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
