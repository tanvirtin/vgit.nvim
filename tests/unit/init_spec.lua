local vgit = require('vgit')

local it = it
local describe = describe

describe('init:', function()

      describe('imports', function()

        it('should make sure all necessary functionalities get exposed', function()
            local known_imports = {
                _tear_down = true,
                _buf_attach = true,
                _buf_detach = true,
                _close_preview_window = true,
                _blame_line = true,
                _unblame_line = true,
                _run_command = true,
                setup = true,
                toggle_buffer_hunks = true,
                toggle_buffer_blames = true,
                hunk_preview = true,
                hunk_up = true,
                hunk_down = true,
                hunk_reset = true,
                buffer_preview = true,
                buffer_reset = true,
                hunks_quickfix_list = true,
            }
            for key, _ in pairs(vgit) do
                assert(known_imports[key])
            end
            for key, _ in pairs(vgit) do
                assert(vgit[key])
            end
        end)

    end)

end)
