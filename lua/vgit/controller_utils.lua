local git = require('vgit.git')
local fs = require('vgit.fs')
local buffer = require('vgit.buffer')
local events = require('vgit.events')
local controller_store = require('vgit.stores.controller_store')

local M = {}

M.store_buf = function(buf, filename, tracked_filename, tracked_remote_filename)
    buffer.store.add(buf)
    local filetype = fs.filetype(buf)
    if not filetype or filetype == '' then
        filetype = fs.detect_filetype(filename)
    end
    buffer.store.set(buf, 'filetype', filetype)
    buffer.store.set(buf, 'filename', filename)
    if tracked_filename and tracked_filename ~= '' then
        buffer.store.set(buf, 'tracked_filename', tracked_filename)
        buffer.store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
        return
    end
    buffer.store.set(buf, 'untracked', true)
end

M.attach_blames_autocmd = function(buf)
    events.buf.on(buf, 'CursorHold', string.format(':lua require("vgit")._blame_line(%s)', buf))
    events.buf.on(buf, 'CursorMoved', string.format(':lua require("vgit")._unblame_line(%s)', buf))
end

M.detach_blames_autocmd = function(buf)
    events.off(string.format('%s/CursorHold', buf))
    events.off(string.format('%s/CursorMoved', buf))
end

M.get_hunk_calculator = function()
    return (controller_store.get('diff_strategy') == 'remote' and git.remote_hunks) or git.index_hunks
end

M.calculate_hunks = function(buf)
    return M.get_hunk_calculator()(buffer.store.get(buf, 'tracked_filename'))
end

M.get_current_hunk = function(hunks, lnum)
    for i = 1, #hunks do
        local hunk = hunks[i]
        if lnum == 1 and hunk.start == 0 and hunk.finish == 0 then
            return hunk
        end
        if lnum >= hunk.start and lnum <= hunk.finish then
            return hunk
        end
    end
end

return M
