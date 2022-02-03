local Hunk = require('vgit.cli.models.Hunk')
local Versioning = require('vgit.core.Versioning')
local utils = require('vgit.core.utils')
local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Patch = require('vgit.cli.models.Patch')
local Git = require('vgit.cli.Git')
local Object = require('vgit.core.Object')

local GitObject = Object:extend()

function GitObject:new(filename)
  local dirname = fs.dirname(filename)
  return setmetatable({
    dirname = dirname,
    filename = {
      native = filename,
      tracked = nil,
    },
    git = Git:new(dirname),
    hunks = nil,
  }, GitObject)
end

function GitObject:is_tracked()
  return self:tracked_filename() ~= ''
end

function GitObject:is_in_remote()
  return self.git:is_in_remote(self:tracked_filename())
end

function GitObject:tracked_filename()
  if self.filename.tracked == nil then
    -- NOTE: git.tracked_filename will return nil if the file does not exist in the git repo.
    self.filename.tracked = self.git:tracked_filename(self.filename.native)
      or ''
    return self.filename.tracked
  end
  return self.filename.tracked
end

function GitObject:patch_hunk(hunk)
  return Patch:new(self.git:tracked_full_filename(self.filename.native), hunk)
end

function GitObject:stage_hunk_from_patch(patch)
  local patch_filename = fs.tmpname()
  fs.write_file(patch_filename, patch)
  loop.await_fast_event()
  local err = self.git:stage_hunk_from_patch(patch_filename)
  loop.await_fast_event()
  fs.remove_file(patch_filename)
  loop.await_fast_event()
  return err
end

function GitObject:stage_hunk(hunk)
  return self:stage_hunk_from_patch(self:patch_hunk(hunk))
end

function GitObject:stage()
  local filename = self:tracked_filename()
  if not self:is_tracked() then
    filename = utils.str.strip(self.filename.native, self.dirname)
  end
  return self.git:stage_file(filename)
end

function GitObject:unstage()
  return self.git:unstage_file(self:tracked_filename())
end

function GitObject:is_inside_git_dir()
  return self.git:is_inside_git_dir()
end

function GitObject:lines(commit_hash)
  commit_hash = commit_hash or ''
  return self.git:show(self:tracked_filename(), commit_hash)
end

function GitObject:is_ignored()
  return self.git:is_ignored(self.filename.native)
end

function GitObject:blame_line(lnum)
  return self.git:blame_line(self:tracked_filename(), lnum, {
    is_background = true,
  })
end

function GitObject:blames()
  return self.git:blames(self:tracked_filename(), {
    is_background = true,
  })
end

function GitObject:config()
  return self.git:config({
    is_background = true,
  })
end

function GitObject:native_hunks(filename, current_lines)
  if filename == '' then
    local hunks = self.git:untracked_hunks(current_lines)
    self.hunks = hunks
    return nil, hunks
  end
  local original_lines_err, original_lines = self:lines()
  loop.await_fast_event()
  if original_lines_err then
    return original_lines_err
  end
  local o_lines_str = ''
  local c_lines_str = ''
  local num_lines = math.max(#original_lines, #current_lines)
  for i = 1, num_lines do
    local o_line = original_lines[i]
    local c_line = current_lines[i]
    if o_line then
      o_lines_str = o_lines_str .. original_lines[i] .. '\n'
    end
    if c_line then
      c_lines_str = c_lines_str .. current_lines[i] .. '\n'
    end
  end
  self.hunks = {}
  local hunks = self.hunks
  vim.diff(o_lines_str, c_lines_str, {
    on_hunk = function(start_o, count_o, start_c, count_c)
      local hunk = Hunk:new({ { start_o, count_o }, { start_c, count_c } })
      hunks[#hunks + 1] = hunk
      if count_o > 0 then
        for i = start_o, start_o + count_o - 1 do
          hunk.diff[#hunk.diff + 1] = '-' .. (original_lines[i] or '')
          hunk.stat.removed = hunk.stat.removed + 1
        end
      end
      if count_c > 0 then
        for i = start_c, start_c + count_c - 1 do
          hunk.diff[#hunk.diff + 1] = '+' .. (current_lines[i] or '')
          hunk.stat.added = hunk.stat.added + 1
        end
      end
    end,
    algorithm = 'myers',
  })
  return nil, hunks
end

function GitObject:piped_hunks(filename, current_lines)
  if filename == '' then
    local hunks = self.git:untracked_hunks(current_lines)
    self.hunks = hunks
    return nil, hunks
  end
  local temp_filename_b = fs.tmpname()
  local temp_filename_a = fs.tmpname()
  local original_lines_err, original_lines = self:lines()
  loop.await_fast_event()
  if original_lines_err then
    return original_lines_err
  end
  fs.write_file(temp_filename_a, original_lines)
  loop.await_fast_event()
  fs.write_file(temp_filename_b, current_lines)
  loop.await_fast_event()
  local hunks_err, hunks = self.git:file_hunks(temp_filename_a, temp_filename_b)
  loop.await_fast_event()
  fs.remove_file(temp_filename_a)
  loop.await_fast_event()
  fs.remove_file(temp_filename_b)
  loop.await_fast_event()
  if not hunks_err then
    self.hunks = hunks
  end
  return hunks_err, hunks
end

function GitObject:live_hunks(current_lines)
  loop.await_fast_event()
  local filename = self:tracked_filename()
  local inexpensive_lines_limit = 5000
  if #current_lines > inexpensive_lines_limit then
    return self:piped_hunks(filename, current_lines)
  end
  local versioning = Versioning:new()
  local version = versioning:neovim_version()
  if version.minor <= 5 then
    return self:piped_hunks(filename, current_lines)
  end
  return self:native_hunks(filename, current_lines)
end

function GitObject:staged_hunks()
  return self.git:staged_hunks(self:tracked_filename())
end

function GitObject:remote_hunks(parent_hash, commit_hash)
  return self.git:remote_hunks(self:tracked_filename(), parent_hash, commit_hash, {
    is_background = true,
  })
end

function GitObject:logs()
  return self.git:logs(self:tracked_filename(), {
    is_background = true,
  })
end

return GitObject
