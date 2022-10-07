local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_setting = require('vgit.settings.git')
local Log = require('vgit.services.git.models.Log')
local Hunk = require('vgit.services.git.models.Hunk')
local Blame = require('vgit.services.git.models.Blame')
local Patch = require('vgit.services.git.models.Patch')
local Status = require('vgit.services.git.models.Status')
local GitReadStream = require('vgit.services.git.GitReadStream')

local GitBlob = Object:extend()

function GitBlob:constructor(filename, status, log)
  filename = filename:gsub('"', '')
  local dirname = fs.dirname(filename)
  local is_dir = fs.is_dir(filename)
  local filetype = fs.detect_filetype(filename)

  return {
    id = utils.math.uuid(),
    commit = 'HEAD',
    filename = filename,
    filename_relative = fs.make_relative(filename, dirname),
    filename_tree = nil,
    dirname = dirname,
    status = status or Status('??'),
    log = log,
    hunks = nil,
    line_blames = {},
    config = nil,
    is_dir = is_dir,
    filetype = filetype,
    git_config = {
      cmd = git_setting:get('cmd'),
      fallback_args = vim.deepcopy(git_setting:get('fallback_args')),
    },
  }
end

function GitBlob:get_filename() return self.filename end

function GitBlob:get_filetype() return self.filetype end

GitBlob.get_object_id = loop.promisify(function(self, callback)
  local err = {}
  local result = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'rev-parse',
      string.format(':%s', self.filename_relative),
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      local object_id = result[1]

      if #err ~= 0 then
        return callback(err, nil)
      end

      callback(nil, object_id)
    end,
    is_background = true,
  }):start()
end, 2)

GitBlob.get_filename_in_tree = loop.promisify(function(self, callback)
  if self.filename_tree then
    return callback(nil, self.filename_tree)
  end

  local err = {}
  local result = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      '--no-pager',
      'ls-files',
      '--exclude-standard',
      '--full-name',
      self.filename_relative,
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      local filename_tree = result[1]

      if #err ~= 0 then
        return callback(err, nil)
      end

      self.filename_tree = filename_tree

      callback(nil, filename_tree)
    end,
  }):start()
end, 2)

GitBlob.get_status = loop.promisify(function(self, callback)
  if self.status then
    return callback(nil, self.status)
  end

  local err = {}
  local status = nil

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      '--no-pager',
      'status',
      '-u',
      '-s',
      '--no-renames',
      '--ignore-submodules',
      '--',
      self.filename_relative,
    }),
    on_stdout = function(line)
      local filename = line:sub(4, #line)

      if fs.is_dir(filename) then
        return
      end

      status = Status(line:sub(1, 2))
    end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      self.status = status

      callback(nil, status)
    end,
    is_background = true,
  }):start()
end, 2)

function GitBlob:is_tracked()
  local _, filename_tree = self:get_filename_in_tree()
  return filename_tree ~= nil
end

GitBlob.is_in_remote = loop.promisify(function(self, callback)
  local err = false

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'show',
      -- git will attach self.dirname to the command which means we are going to search
      -- from the current relative path "./" basically just means "${self.dirname}/".
      string.format('%s:./%s', self.commit, self.filename_relative),
    }),
    on_stderr = function(line)
      if line then
        err = true
      end
    end,
    on_exit = function() callback(not err) end,
    is_background = true,
  }):start()
end, 2)

function GitBlob:patch_hunk(hunk)
  local _, filename_tree = self:get_filename_in_tree()
  return Patch(filename_tree, hunk)
end

GitBlob.stage_hunk_from_patch_file = loop.promisify(function(self, patch_filename, callback)
  local err = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      '--no-pager',
      'apply',
      '--cached',
      '--whitespace=nowarn',
      '--unidiff-zero',
      patch_filename,
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }):start()
end, 3)

GitBlob.unstage_hunk_from_patch_file = loop.promisify(function(self, patch_filename, callback)
  local err = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      '--no-pager',
      'apply',
      '--reverse',
      '--cached',
      '--whitespace=nowarn',
      '--unidiff-zero',
      patch_filename,
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }):start()
end, 3)

function GitBlob:stage_hunk_from_patch(patch)
  local patch_filename = fs.tmpname()

  fs.write_file(patch_filename, patch)

  loop.await()
  local err = self:stage_hunk_from_patch_file(patch_filename)

  loop.await()
  fs.remove_file(patch_filename)
  loop.await()

  return err
end

function GitBlob:unstage_hunk_from_patch(patch)
  local patch_filename = fs.tmpname()

  fs.write_file(patch_filename, patch)

  loop.await()
  local err = self:unstage_hunk_from_patch_file(patch_filename)

  loop.await()
  fs.remove_file(patch_filename)
  loop.await()

  return err
end

function GitBlob:stage_hunk(hunk) return self:stage_hunk_from_patch(self:patch_hunk(hunk)) end

function GitBlob:unstage_hunk(hunk) return self:unstage_hunk_from_patch(self:patch_hunk(hunk)) end

GitBlob.stage = loop.promisify(function(self, callback)
  local err = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      '--no-pager',
      'add',
      '--',
      self.filename_relative,
    }),
    on_stderr = function(line)
      local is_warning, _ = line:find('warning')

      if not is_warning then
        err[#err + 1] = line
      end
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }):start()
end, 2)

GitBlob.unstage = loop.promisify(function(self, callback)
  local err = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'reset',
      '-q',
      'HEAD',
      '--',
      self.filename_relative,
    }),
    on_stderr = function(line)
      local is_warning, _ = line:find('warning')

      if not is_warning then
        err[#err + 1] = line
      end
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }):start()
end, 2)

GitBlob.show = loop.promisify(function(self, commit, callback)
  local err = {}
  local result = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'show',
      string.format('%s:./%s', commit or self.commit, self.filename_relative),
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      callback(nil, result)
    end,
  }):start()
end, 3)

function GitBlob:get_lines(commit) return self:show(commit or '') end

GitBlob.get_line_blame = loop.promisify(function(self, lnum, callback)
  local err = {}
  local result = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'blame',
      '-L',
      string.format('%s,+1', lnum),
      '--line-porcelain',
      '--',
      self.filename_relative,
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      callback(nil, Blame(result))
    end,
    is_background = true,
  }):start()
end, 3)

function GitBlob:blame_line(lnum)
  if self.line_blames[lnum] then
    return nil, self.line_blames[lnum]
  end

  local err, blame = self:get_line_blame(lnum)

  if blame then
    self.line_blames[lnum] = blame
  end

  return err, blame
end

GitBlob.get_line_blames = loop.promisify(function(self, callback)
  local err = {}
  local result = {}
  local blame_info = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'blame',
      '--line-porcelain',
      '--',
      self.filename_relative,
    }),
    on_stdout = function(line)
      if string.byte(line:sub(1, 3)) ~= 9 then
        table.insert(blame_info, line)
      else
        local blame = Blame(blame_info)

        if blame then
          result[#result + 1] = blame
        end

        blame_info = {}
      end
    end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      callback(nil, result)
    end,
    is_background = true,
  }):start()
end, 2)

function GitBlob:blame_lines() return self:get_line_blames() end

GitBlob.get_config = loop.promisify(function(self, callback)
  if self.config then
    return callback(nil, self.config)
  end

  local err = {}
  local result = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'config',
      '--list',
    }),
    on_stdout = function(line)
      local line_chunks = vim.split(line, '=')

      result[line_chunks[1]] = line_chunks[2]
    end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      self.config = result

      callback(nil, result)
    end,
    is_background = true,
  }):start()
end, 2)

function GitBlob:untracked_hunks(lines)
  local diff = {}

  for i = 1, #lines do
    diff[#diff + 1] = string.format('+%s', lines[i])
  end

  local hunk = Hunk()

  hunk.header = hunk:generate_header({ 0, 0 }, { 1, #lines })
  hunk.top = 1
  hunk.bot = #lines
  hunk.type = 'add'
  hunk.diff = diff
  hunk.stat = {
    added = #lines,
    removed = 0,
  }

  return nil, { hunk }
end

GitBlob.file_hunks = loop.promisify(function(self, filename_a, filename_b, callback)
  local algorithm = 'myers'
  local err = {}
  local result = {}

  local args = utils.list.merge(self.git_config.fallback_args, {
    '-C',
    self.dirname,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--no-index',
    filename_a,
    filename_b,
  })

  GitReadStream({
    command = self.git_config.cmd,
    args = args,
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      local hunks = {}

      for i = 1, #result do
        local line = result[i]

        if vim.startswith(line, '@@') then
          hunks[#hunks + 1] = Hunk(line)
        else
          if #hunks > 0 then
            local hunk = hunks[#hunks]
            hunk:push(line)
          end
        end
      end

      return callback(nil, hunks)
    end,
    is_background = true,
  }):start()
end, 4)

function GitBlob:native_hunks(current_lines)
  if not self.filename_relative then
    local _, hunks = self:untracked_hunks(current_lines)

    self.hunks = hunks
    return nil, hunks
  end

  local original_lines_err, original_lines = self:get_lines()

  loop.await()
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

function GitBlob:piped_hunks(current_lines)
  if not self.filename_relative then
    local _, hunks = self:untracked_hunks(current_lines)
    self.hunks = hunks
    return nil, hunks
  end

  local temp_filename_b = fs.tmpname()
  local temp_filename_a = fs.tmpname()
  local original_lines_err, original_lines = self:get_lines()

  loop.await()
  if original_lines_err then
    return original_lines_err
  end

  fs.write_file(temp_filename_a, original_lines)
  loop.await()
  fs.write_file(temp_filename_b, current_lines)
  loop.await()

  local hunks_err, hunks = self:file_hunks(temp_filename_a, temp_filename_b)

  loop.await()
  fs.remove_file(temp_filename_a)
  loop.await()
  fs.remove_file(temp_filename_b)
  loop.await()

  if not hunks_err then
    self.hunks = hunks
  end

  return hunks_err, hunks
end

function GitBlob:live_hunks(current_lines)
  loop.await()
  local inexpensive_lines_limit = 5000

  if #current_lines > inexpensive_lines_limit then
    return self:piped_hunks(current_lines)
  end

  return self:native_hunks(current_lines)
end

GitBlob.staged_hunks = loop.promisify(function(self, callback)
  local algorithm = 'myers'
  local err = {}
  local result = {}

  local args = utils.list.merge(self.git_config.fallback_args, {
    '-C',
    self.dirname,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--cached',
    '--',
    self.filename_relative,
  })

  GitReadStream({
    command = self.git_config.cmd,
    args = args,
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      local hunks = {}

      for i = 1, #result do
        local line = result[i]

        if vim.startswith(line, '@@') then
          hunks[#hunks + 1] = Hunk(line)
        else
          if #hunks > 0 then
            local hunk = hunks[#hunks]
            hunk:push(line)
          end
        end
      end
      return callback(nil, hunks)
    end,
  }):start()
end, 2)

GitBlob.remote_hunks = loop.promisify(function(self, parent_commit, commit, callback)
  local err = {}
  local result = {}
  local algorithm = 'myers'

  local args = utils.list.merge(self.git_config.fallback_args, {
    '-C',
    self.dirname,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', algorithm),
    '--patch-with-raw',
    '--unified=0',
  })

  if parent_commit and commit then
    utils.list.concat(args, {
      #parent_commit > 0 and parent_commit or self.empty_tree_hash,
      commit,
      '--',
      self.filename_relative,
    })
  elseif parent_commit and not commit then
    utils.list.concat(args, {
      parent_commit,
      '--',
      self.filename_relative,
    })
  else
    utils.list.concat(args, {
      '--',
      self.filename_relative,
    })
  end

  GitReadStream({
    command = self.git_config.cmd,
    args = args,
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      local hunks = {}

      for i = 1, #result do
        local line = result[i]

        if vim.startswith(line, '@@') then
          hunks[#hunks + 1] = Hunk(line)
        else
          if #hunks > 0 then
            local hunk = hunks[#hunks]
            hunk:push(line)
          end
        end
      end

      return callback(nil, hunks)
    end,
  }):start()
end, 4)

GitBlob.get_logs = loop.promisify(function(self, callback)
  local err = {}
  local logs = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'log',
      '--color=never',
      '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
      '--',
      self.filename_relative,
    }),
    on_stdout = function(line)
      local log = Log(line)

      if log then
        logs[#logs + 1] = log
      end
    end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      return callback(nil, logs)
    end,
    is_background = true,
  }):start()
end, 2)

function GitBlob:generate_diff_status()
  local hunks = self.hunks or {}
  local stats_dict = {
    added = 0,
    changed = 0,
    removed = 0,
  }
  for _, h in ipairs(hunks) do
    -- hunk stats only contain added/removed, lines that
    -- are both added and removed are considered "changed"
    local changed = math.min(h.stat.added, h.stat.removed)
    stats_dict.added = stats_dict.added + math.abs(h.stat.added - changed)
    stats_dict.removed = stats_dict.removed + math.abs(h.stat.removed - changed)
    stats_dict.changed = stats_dict.changed + changed
  end
  return stats_dict
end

GitBlob.is_inside_git_dir = loop.promisify(function(self, callback)
  local err = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      'rev-parse',
      '--is-inside-git-dir',
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(nil, false)
      end

      callback(nil, true)
    end,
    is_background = true,
  }):start()
end, 2)

GitBlob.is_ignored = loop.promisify(function(self, callback)
  local err = {}

  GitReadStream({
    command = self.git_config.cmd,
    args = utils.list.merge(self.git_config.fallback_args, {
      '-C',
      self.dirname,
      '--no-pager',
      'check-ignore',
      self.filename_relative,
    }),
    on_stdout = function(line) err[#err + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(nil, true)
      end

      callback(nil, false)
    end,
    is_background = true,
  }):start()
end, 2)

function GitBlob:is_staged()
  local _, status = self:get_status()

  return status:has('* ')
end

function GitBlob:is_unstaged()
  local _, status = self:get_status()

  return status:has(' *')
end

function GitBlob:has_conflict()
  local _, status = self:get_status()

  return status:has('UU')
end

function GitBlob:is_untracked()
  local _, status = self:get_status()

  return status:has('??')
end

return GitBlob
