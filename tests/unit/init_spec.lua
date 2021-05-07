local git = require('git')

local it = it
local describe = describe

describe('init:', function()

      describe('imports', function()

        it('should make sure all necessary functionalities get exposed', function()
            local known_imports = {
                setup = true,
                tear_down = true,
                buf_attach = true,
                buf_detach = true,
                hunk_preview = true,
                hunk_up = true,
                hunk_down = true,
                hunk_reset = true,
                buffer_preview = true,
                buffer_reset = true,
                close_preview_window = true,
                toggle_buffer_hunks = true,
                toggle_buffer_blames = true,
                blame_line = true,
                unblame_line = true,
            }
            for key, _ in pairs(git) do
                assert(known_imports[key])
            end
            for key, _ in pairs(git) do
                assert(git[key])
            end
        end)

    end)

end)
