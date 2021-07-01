local vgit = require('vgit')

local it = it
local describe = describe

describe('init:', function()

      describe('imports', function()

        it('should make sure all necessary functionalities get exposed', function()
            local known_imports = {
                diff = true,
                setup = true,
                enabled = true,
                hunk_up = true,
                hunk_down = true,
                hunk_reset = true,
                show_blame = true,
                buffer_diff = true,
                buffer_reset = true,
                instantiated = true,
                hunk_preview = true,
                set_diff_base = true,
                get_diff_base = true,
                buffer_preview = true,
                buffer_history = true,
                show_debug_logs = true,
                apply_highlights = true,
                get_diff_strategy = true,
                set_diff_strategy = true,
                get_diff_preference = true,
                set_diff_preference = true,
                toggle_buffer_hunks = true,
                hunks_quickfix_list = true,
                toggle_buffer_blames = true,
                get_hunk_prediction_strategy = true,
                set_hunk_prediction_strategy = true,
                _buf_attach = true,
                _buf_update = true,
                _blame_line = true,
                _run_command = true,
                _unblame_line = true,
                _change_history = true,
                _command_autocompletes = true,
                _run_submodule_command = true,
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
