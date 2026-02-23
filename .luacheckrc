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
    "631", -- Line too long (stylua handles line length)
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

local test_settings = {
    ignore = {
        "143", -- accessing undefined field of global (assert.are.same, assert.is_true, etc.)
        "211", -- unused variable (common in tests: local eq = ..., local _, err = ...)
        "231", -- variable never accessed in for loop (common in destructured returns)
    },
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

files["tests/"] = test_settings
files["lua/**/*_spec.lua"] = test_settings
