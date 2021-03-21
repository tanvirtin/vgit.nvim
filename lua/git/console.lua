local console = {}

console.log = function(str)
    vim.schedule(function()
        vim.cmd('echo "' .. str.. '"')
    end)
end

return console;
