local git = require('git')

local it = it
local describe = describe

describe('init:', function()

      describe('imports', function()

        it('should make sure all necessary functionalities get exposed', function()
            local known_imports = {
                setup = true,
                buf_attach = true,
                buf_detach = true,
                hunk_preview = true,
                hunk_up = true,
                hunk_down = true,
                hunk_reset = true,
                diff = true,
                files_changed = true
            }
            for key, _ in pairs(git) do
                assert(known_imports[key])
            end
        end)

    end)

end)
