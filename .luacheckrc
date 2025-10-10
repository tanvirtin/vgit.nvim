cache = true

std = luajit
codes = true

self = false

ignore = {
    "212", -- Unused argument, In the case of callback function, _arg_name is easier to understand than _, so this option is set to off.
    "122", -- Indirectly setting a readonly global
    "311", -- Value assigned to a variable is unused (common pattern for opts parameters)
    "312", -- Value of argument is unused (common pattern for destructuring)
    "512", -- Loop is executed at most once (intentional in utils.object.first)
}

globals = {
    "_",
}

read_globals = {
    "vim",
}

exclude_files = {
    "lua/vgit/lib/*",
    "lua/vgit/vendor/*",
}

files["tests/"] = {
    ignore = { "143" },
    read_globals = {
        "describe",
        "it",
        "before_each",
        "after_each",
        "assert",
        "spy",
        "stub",
        "mock",
    },
}
