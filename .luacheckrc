cache = true

std = luajit

codes = true
self = false
unused_args = false
unused = true

ignore = {
    "122", -- Indirectly setting a readonly global
    "431", -- Shadowing upvalue (acceptable in local scopes)
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
