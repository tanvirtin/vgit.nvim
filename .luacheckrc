cache = true

std = luajit
codes = true

self = false

ignore = {
    "212", -- Unused argument, In the case of callback function, _arg_name is easier to understand than _, so this option is set to off.
    "122", -- Indirectly setting a readonly global
}

globals = {
    "_",
}

read_globals = {
    "vim",
}

exclude_files = {
    "lua/vgit/lib/*",
}
