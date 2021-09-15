local utils = require('vgit.utils')
local change = require('vgit.change')
local Hunk = require('vgit.Hunk')
local git = require('vgit.git')
local renderer = require('vgit.renderer')
local fs = require('vgit.fs')
local buffer = require('vgit.buffer')
local throttle_leading = require('vgit.defer').throttle_leading
local controller_store = require('vgit.stores.controller_store')
local logger = require('vgit.logger')
local wrap = require('plenary.async.async').wrap
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler
local controller_utils = require('vgit.controller_utils')

local M = {}

M._rerender_history = throttle_leading(
    void(function(buf)
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        if buffer.is_being_edited(buf) then
            return
        end
        local selected_log = vim.api.nvim_win_get_cursor(0)[1]
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.rerender_history_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                local logs = buffer.store.get(buf, 'logs')
                local log = logs[selected_log]
                local err, hunks, lines, commit_hash, computed_hunks
                if not log then
                    return { 'Failed to access logs' }, nil
                end
                if selected_log == 1 then
                    local temp_lines = buffer.store.get(buf, 'temp_lines')
                    if #temp_lines ~= 0 then
                        lines = temp_lines
                        computed_hunks = buffer.store.get(buf, 'hunks')
                    else
                        err, computed_hunks = git.remote_hunks(tracked_filename, 'HEAD')
                    end
                else
                    err, computed_hunks = git.remote_hunks(tracked_filename, log.parent_hash, log.commit_hash)
                end
                scheduler()
                if err then
                    logger.debug(err, 'init.lua/_rerender_history')
                    return err, nil
                end
                hunks = computed_hunks
                commit_hash = log.commit_hash
                if commit_hash and not lines then
                    err, lines = git.show(buffer.store.get(buf, 'tracked_remote_filename'), commit_hash)
                    scheduler()
                elseif not lines then
                    err, lines = fs.read_file(tracked_filename)
                    scheduler()
                end
                if err then
                    logger.debug(err, 'init.lua/_rerender_history')
                    return err, nil
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        logs = logs,
                        diff_change = data,
                    })
            end, 0),
            selected_log
        )
    end),
    controller_store.get('action_delay_ms')
)

M._rerender_project_diff = throttle_leading(
    void(function()
        if controller_store.get('disabled') then
            return
        end
        local selected_file = vim.api.nvim_win_get_cursor(0)[1]
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.rerender_project_diff_preview(
            wrap(function()
                local changed_files_err, changed_files = git.ls_changed()
                scheduler()
                if changed_files_err then
                    logger.debug(changed_files_err, 'init.lua/_rerender_project_diff')
                    return changed_files_err, nil
                end
                local file = changed_files[selected_file]
                if not file then
                    return { 'File not found' },
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local filename = file.filename
                local hunk_calculator = controller_utils.get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/_rerender_project_diff')
                    return hunks_err, nil
                end
                local files_err, lines = fs.read_file(filename)
                if files_err then
                    logger.debug(files_err, 'init.lua/_rerender_project_diff')
                    return files_err,
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        changed_files = changed_files,
                        diff_change = data,
                        filetype = fs.detect_filetype(filename),
                    })
            end, 0),
            selected_file
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_gutter_blame_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        renderer.render_gutter_blame_preview(
            wrap(function()
                local filename = buffer.store.get(buf, 'tracked_filename')
                local read_file_err, lines = fs.read_file(filename)
                scheduler()
                if read_file_err then
                    logger.debug(read_file_err, 'init.lua/buffer_gutter_blame_preview')
                    return read_file_err, nil
                end
                local blames_err, blames = git.blames(filename)
                scheduler()
                if blames_err then
                    logger.debug(blames_err, 'init.lua/buffer_gutter_blame_preview')
                    return blames_err, nil
                end
                local hunk_calculator = controller_utils.get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/buffer_gutter_blame_preview')
                    return hunks_err, nil
                end
                return nil,
                    {
                        blames = blames,
                        lines = lines,
                        hunks = hunks,
                    }
            end, 0),
            buffer.store.get(buf, 'filetype')
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_blame_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local has_commits = git.has_commits()
        scheduler()
        if not has_commits then
            return
        end
        local win = vim.api.nvim_get_current_win()
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        renderer.render_blame_preview(wrap(function()
            local err, blame = git.blame_line(buffer.store.get(buf, 'tracked_filename'), lnum)
            scheduler()
            return err, blame
        end, 0))
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_history_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.render_history_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                local logs_err, logs = git.logs(tracked_filename)
                scheduler()
                if logs_err then
                    logger.debug(logs_err, 'init.lua/buffer_history_preview')
                    return logs_err, nil
                end
                buffer.store.set(buf, 'logs', logs)
                local temp_lines = buffer.store.get(buf, 'temp_lines')
                if #temp_lines ~= 0 then
                    local lines = temp_lines
                    local hunks = buffer.store.get(buf, 'hunks')
                    local data = calculate_change(lines, hunks)
                    return nil,
                        utils.readonly({
                            logs = logs,
                            diff_change = data,
                        })
                end
                local read_file_err, lines = fs.read_file(tracked_filename)
                scheduler()
                if read_file_err then
                    logger.debug(read_file_err, 'init.lua/buffer_history_preview')
                    return read_file_err, nil
                end
                local hunks_err, hunks = git.remote_hunks(tracked_filename, 'HEAD')
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/buffer_history_preview')
                    return hunks_err, nil
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        logs = logs,
                        diff_change = data,
                    })
            end, 0),
            buffer.store.get(buf, 'filetype'),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_hunk_preview = throttle_leading(
    void(function(buf, win)
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not controller_store.get('hunks_enabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local hunks = buffer.store.get(buf, 'hunks')
        if #hunks == 0 then
            logger.info('No changes found')
            return
        end
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        renderer.render_hunk_preview(
            wrap(function()
                local read_file_err, lines = fs.read_file(buffer.store.get(buf, 'tracked_filename'))
                scheduler()
                if read_file_err then
                    logger.debug(read_file_err, 'init.lua/buffer_hunk_preview')
                    return read_file_err, nil
                end
                local data = change.horizontal(lines, hunks)
                return nil,
                    {
                        diff_change = data,
                        selected_hunk = controller_utils.get_current_hunk(hunks, lnum) or Hunk:new(),
                    }
            end, 0),
            buffer.store.get(buf, 'filetype')
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_diff_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if not buffer.store.contains(buf) then
            return
        end
        if not controller_store.get('hunks_enabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local hunks = buffer.store.get(buf, 'hunks')
        if #hunks == 0 then
            logger.info('No changes found')
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.render_diff_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                if not hunks then
                    return { 'Failed to retrieve hunks for the current buffer' }, nil
                end
                local temp_lines = buffer.store.get(buf, 'temp_lines')
                local read_file_err, lines
                if #temp_lines ~= 0 then
                    lines = temp_lines
                else
                    read_file_err, lines = fs.read_file(tracked_filename)
                    scheduler()
                    if read_file_err then
                        logger.debug(read_file_err, 'init.lua/buffer_diff_preview')
                        return read_file_err, nil
                    end
                end
                local data = calculate_change(lines, hunks)
                scheduler()
                return nil, {
                    diff_change = data,
                }
            end, 0),
            buffer.store.get(buf, 'filetype'),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_staged_diff_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        if controller_store.get('diff_strategy') ~= 'index' then
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.render_diff_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                local hunks_err, hunks = git.staged_hunks(tracked_filename)
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/buffer_staged_diff_preview')
                    return hunks_err, nil
                end
                scheduler()
                local show_err, lines = git.show(buffer.store.get(buf, 'tracked_remote_filename'))
                scheduler()
                if show_err then
                    logger.debug(show_err, 'init.lua/buffer_staged_diff_preview')
                    return show_err, nil
                end
                local data = calculate_change(lines, hunks)
                scheduler()
                return nil, {
                    diff_change = data,
                }
            end, 0),
            buffer.store.get(buf, 'filetype'),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.project_diff_preview = throttle_leading(
    void(function()
        if controller_store.get('disabled') then
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        local changed_files_err, changed_files = git.ls_changed()
        scheduler()
        if changed_files_err then
            return logger.debug(changed_files_err, 'init.lua/project_diff_preview')
        end
        if #changed_files == 0 then
            logger.info('No changes found')
            return
        end
        renderer.render_project_diff_preview(
            wrap(function()
                local selected_file = 1
                local file = changed_files[selected_file]
                if not file then
                    return { 'File not found' },
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local filename = file.filename
                local hunk_calculator = controller_utils.get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/project_diff_preview')
                    return hunks_err, nil
                end
                local files_err, lines = fs.read_file(filename)
                if files_err then
                    logger.debug(files_err, 'init.lua/project_diff_preview')
                    return files_err,
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        changed_files = changed_files,
                        diff_change = data,
                        filetype = fs.detect_filetype(filename),
                    })
            end, 0),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.project_hunks_qf = throttle_leading(
    void(function()
        if not controller_store.get('disabled') then
            local qf_entries = {}
            local err, filenames = git.ls_changed()
            scheduler()
            if err then
                return logger.debug(err, 'init.lua/project_hunks_qf')
            end
            for i = 1, #filenames do
                local filename = filenames[i].filename
                local hunk_calculator = controller_utils.get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                scheduler()
                if not hunks_err then
                    for j = 1, #hunks do
                        local hunk = hunks[j]
                        qf_entries[#qf_entries + 1] = {
                            text = string.format('[%s..%s]', hunk.start, hunk.finish),
                            filename = filename,
                            lnum = hunk.start,
                            col = 0,
                        }
                    end
                else
                    logger.debug(hunks_err, 'init.lua/project_hunks_qf')
                end
            end
            if #qf_entries ~= 0 then
                vim.fn.setqflist(qf_entries, 'r')
                vim.cmd('copen')
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.actions = function()
    if not pcall(require, 'telescope') then
        logger.info('Please install https://github.com/nvim-telescope/telescope.nvim to use the command palette')
        return
    end
    local actions = {
        'project_diff_preview | Opens preview of all the changes in your current project',
        'project_hunks_qf | Opens quickfix list with all the changes as hunks in your current project',
        'buffer_diff_preview | Opens preview of the changes in the current buffer',
        'buffer_staged_diff_preview | Opens preview of all the staged changes for your current buffer',
        'buffer_hunk_preview | Opens preview of the changes in the current buffer hunk',
        'buffer_history_preview | Opens preview of all the changes throughout time for the current buffer',
        'buffer_blame_preview | Opens preview of showing the blame details of the current line for the current buffer',
        'buffer_gutter_blame_preview | Opens preview of showing all blame details for the current buffer',
        'buffer_reset | Reset all the changes on the current buffer',
        'buffer_hunk_stage | Stage the current hunk the cursor is currently on in your current buffer',
        'buffer_stage | Stage the current buffer',
        'buffer_unstage | Unstage the current buffer',
        'buffer_hunk_reset | Reset the current hunk the cursor is onin your current buffer',
        'toggle_buffer_hunks | Enables buffer signs on/Disables buffer signs off',
        'toggle_buffer_blames | Enables current line blames/Disables current buffer line blames',
        'toggle_diff_preference | Toggles between "Horizontal" and "Vertical" diff preference',
        'hunk_up | Navigates up on to a change on any buffer or preview',
        'hunk_down | Navigates down on to a change on any buffer or preview',
        'apply_highlights | Applies all the current highlights, useful when changing colorschemes',
    }
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local telescope_actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    pickers.new({ layout_strategy = 'bottom_pane', layout_config = { height = #actions } }, {
        prompt_title = 'VGit',
        finder = finders.new_table(actions),
        sorter = conf.generic_sorter(),
        attach_mappings = function(buf, map)
            map(
                'i',
                '<cr>',
                void(function()
                    local selected = action_state.get_selected_entry()
                    local value = selected.value
                    local command = vim.trim(vim.split(value, '|')[1])
                    telescope_actions.close(buf)
                    scheduler()
                    require('vgit')[command]()
                end)
            )
            return true
        end,
    }):find()
end

return M
