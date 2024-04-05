local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local Hunk = require('vgit.git.cli.models.Hunk')
local Patch = require('vgit.git.cli.models.Patch')

local GitObject = Object:extend()

function GitObject:constructor(filename)
  local dirname = fs.dirname(filename)

  return {
    git = Git(dirname),
    hunks = nil,
    dirname = dirname,
    filename = {
      native = filename,
      tracked = nil,
    },
    filetype = fs.detect_filetype(filename),
    _cache = {
      line_blames = {},
    },
  }
end

function GitObject:is_inside_git_dir()
  return self.git:is_inside_git_dir()
end

function GitObject:is_ignored()
  return self.git:is_ignored(self.filename.native)
end

function GitObject:get_filename()
  return self.filename.native
end

function GitObject:get_filetype()
  return self.filetype
end

function GitObject:is_tracked()
  return self:tracked_filename() ~= ''
end

function GitObject:is_in_remote()
  return self.git:is_in_remote(self:tracked_filename())
end

function GitObject:config()
  return self.git:config({ is_background = true })
end

function GitObject:tracked_filename()
  if self.filename.tracked == nil then
    -- NOTE: git.tracked_filename will return nil if the file does not exist in the git repo.
    self.filename.tracked = self.git:tracked_filename(self.filename.native) or ''
    return self.filename.tracked
  end

  return self.filename.tracked
end

function GitObject:patch_hunk(hunk)
  return Patch(self.git:tracked_full_filename(self.filename.native), hunk)
end

function GitObject:stage_hunk_from_patch(patch)
  local patch_filename = fs.tmpname()
  loop.free_textlock()
  fs.write_file(patch_filename, patch)

  loop.free_textlock()
  local err = self.git:stage_hunk_from_patch(patch_filename)

  loop.free_textlock()
  fs.remove_file(patch_filename)

  return err
end

function GitObject:unstage_hunk_from_patch(patch)
  local patch_filename = fs.tmpname()
  loop.free_textlock()
  fs.write_file(patch_filename, patch)

  loop.free_textlock()
  local err = self.git:unstage_hunk_from_patch(patch_filename)

  loop.free_textlock()
  fs.remove_file(patch_filename)

  return err
end

function GitObject:stage_hunk(hunk)
  return self:stage_hunk_from_patch(self:patch_hunk(hunk))
end

function GitObject:unstage_hunk(hunk)
  return self:unstage_hunk_from_patch(self:patch_hunk(hunk))
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

function GitObject:lines(commit_hash)
  return self.git:show(self:tracked_filename(), commit_hash or '', { is_background = true })
end

function GitObject:blame_line(lnum)
  if self._cache.line_blames[lnum] then return nil, self._cache.line_blames[lnum] end

  local err, blame = self.git:blame_line(self:tracked_filename(), lnum, { is_background = true })

  if blame then
    self._cache.line_blames[lnum] = blame
  end

  return err, blame
end

function GitObject:blames()
  return self.git:blames(self:tracked_filename(), { is_background = true })
end

function GitObject:live_hunks(current_lines)
  loop.free_textlock()
  local filename = self:tracked_filename()

  if filename == '' then
    loop.free_textlock()
    local hunks = self.git:untracked_hunks(current_lines)
    self.hunks = hunks
    return nil, hunks
  end

  loop.free_textlock()
  local original_lines_err, original_lines = self:lines()
  if original_lines_err then return original_lines_err end

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

  loop.free_textlock()
  vim.diff(o_lines_str, c_lines_str, {
    on_hunk = function(start_o, count_o, start_c, count_c)
      local hunk = Hunk({ { start_o, count_o }, { start_c, count_c } })

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

function GitObject:staged_hunks()
  return self.git:staged_hunks(self:tracked_filename(), { is_background = true })
end

function GitObject:remote_hunks(parent_hash, commit_hash)
  return self.git:remote_hunks(self:tracked_filename(), parent_hash, commit_hash, { is_background = true })
end

function GitObject:logs()
  return self.git:file_logs(self:tracked_filename(), { is_background = true })
end

function GitObject:status()
  return self.git:file_status(self:tracked_filename())
end

function GitObject:generate_status()
  local hunks = self.hunks or {}
  local stats_dict = { added = 0, changed = 0, removed = 0 }

  for _, h in ipairs(hunks) do
    local changed = math.min(h.stat.added, h.stat.removed)
    stats_dict.added = stats_dict.added + math.abs(h.stat.added - changed)
    stats_dict.removed = stats_dict.removed + math.abs(h.stat.removed - changed)
    stats_dict.changed = stats_dict.changed + changed
  end

  return stats_dict
end

return GitObject
