local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_setting = require('vgit.settings.git')
local Log = require('vgit.services.git.models.Log')
local GitBlob = require('vgit.services.git.GitBlob')
local Hunk = require('vgit.services.git.models.Hunk')
local Blame = require('vgit.services.git.models.Blame')
local Status = require('vgit.services.git.models.Status')
local GitReadStream = require('vgit.services.git.GitReadStream')

local GitClient = Object:extend()

function GitClient:constructor(cwd)
  local newself = {
    cwd = cwd or '',
    cmd = git_setting:get('cmd'),
    fallback_args = {},
    diff_algorithm = 'myers',
    empty_tree_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904',
    state = {
      config = nil,
    },
  }
  if cwd and not self.is_inside_git_dir(newself) then
    newself.cwd = git_setting:get('fallback_cwd') or ''
    newself.fallback_args = vim.deepcopy(git_setting:get('fallback_args'))
  end
  return newself
end

function GitClient:set_cwd(cwd) self.cwd = cwd end

GitClient.is_commit_valid = loop.promisify(function(self, commit, spec, callback)
  local result = {}
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'show',
      '--abbrev-commit',
      '--oneline',
      '--no-notes',
      '--no-patch',
      '--no-color',
      commit,
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(false)
      end
      if #result == 0 then
        return callback(false)
      end
      callback(true)
    end,
  }, spec)):start()
end, 4)

GitClient.config = loop.promisify(function(self, spec, callback)
  if self.state.config then
    return callback(nil, self.state.config)
  end

  local err = {}
  local result = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
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

      self.state.config = result
      callback(nil, result)
    end,
  }, spec)):start()
end, 3)

GitClient.has_commits = loop.promisify(function(self, spec, callback)
  local result = true

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'status',
    }),
    on_stdout = function(line)
      if line == 'No commits yet' then
        result = false
      end
    end,
    on_exit = function() callback(result) end,
  }, spec)):start()
end, 3)

GitClient.is_inside_git_dir = loop.promisify(function(self, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'rev-parse',
      '--is-inside-git-dir',
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(false)
      end

      callback(true)
    end,
  }, spec)):start()
end, 3)

GitClient.blames = loop.promisify(function(self, filename, spec, callback)
  local err = {}
  local result = {}
  local blame_info = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'blame',
      '--line-porcelain',
      '--',
      filename,
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
  }, spec)):start()
end, 4)

GitClient.blame_line = loop.promisify(function(self, filename, lnum, spec, callback)
  filename = fs.make_relative(filename, self.cwd)
  local err = {}
  local result = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'blame',
      '-L',
      string.format('%s,+1', lnum),
      '--line-porcelain',
      '--',
      filename,
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      callback(nil, Blame(result))
    end,
  }, spec)):start()
end, 5)

GitClient.log = loop.promisify(function(self, commit_hash, spec, callback)
  local err = {}
  local logs = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'show',
      commit_hash,
      '--color=never',
      '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
      '--no-patch',
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

      return callback(nil, logs[1])
    end,
  }, spec)):start()
end, 4)

GitClient.logs = loop.promisify(function(self, options, spec, callback)
  local err = {}
  local logs = {}
  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'log',
      '--color=never',
      '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
      '--all',
    }, options),
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
  }, spec)):start()
end, 4)

GitClient.file_logs = loop.promisify(function(self, filename, spec, callback)
  local err = {}
  local logs = {}
  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'log',
      '--color=never',
      '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
      '--',
      filename,
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
  }, spec)):start()
end, 4)

GitClient.file_hunks = loop.promisify(function(self, filename_a, filename_b, spec, callback)
  local result = {}
  local err = {}
  local args = utils.list.merge(self.fallback_args, {
    '-C',
    self.cwd,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', self.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--no-index',
    filename_a,
    filename_b,
  })

  GitReadStream(utils.object.defaults({
    command = self.cmd,
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
  }, spec)):start()
end, 5)

GitClient.index_hunks = loop.promisify(function(self, filename, spec, callback)
  local result = {}
  local err = {}
  local args = utils.list.merge(self.fallback_args, {
    '-C',
    self.cwd,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', self.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--',
    filename,
  })

  GitReadStream(utils.object.defaults({
    command = self.cmd,
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
  }, spec)):start()
end, 4)

GitClient.remote_hunks = loop.promisify(function(self, filename, parent_hash, commit_hash, spec, callback)
  local result = {}
  local err = {}
  local args = utils.list.merge(self.fallback_args, {
    '-C',
    self.cwd,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', self.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
  })

  if parent_hash and commit_hash then
    utils.list.concat(args, {
      #parent_hash > 0 and parent_hash or self.empty_tree_hash,
      commit_hash,
      '--',
      filename,
    })
  elseif parent_hash and not commit_hash then
    utils.list.concat(args, {
      parent_hash,
      '--',
      filename,
    })
  else
    utils.list.concat(args, {
      '--',
      filename,
    })
  end

  GitReadStream(utils.object.defaults({
    command = self.cmd,
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
  }, spec)):start()
end, 6)

GitClient.staged_hunks = loop.promisify(function(self, filename, spec, callback)
  local result = {}
  local err = {}
  local args = utils.list.merge(self.fallback_args, {
    '-C',
    self.cwd,
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', self.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--cached',
    '--',
    filename,
  })

  GitReadStream(utils.object.defaults({
    command = self.cmd,
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
  }, spec)):start()
end, 4)

function GitClient:untracked_hunks(lines)
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

  return { hunk }
end

function GitClient:deleted_hunks(lines)
  local diff = {}

  for i = 1, #lines do
    diff[#diff + 1] = string.format('+%s', lines[i])
  end

  local hunk = Hunk()

  hunk.header = hunk:generate_header({ 1, #lines }, { 0, 0 })
  hunk.top = 1
  hunk.bot = #lines
  hunk.type = 'remove'
  hunk.diff = diff
  hunk.stat = {
    added = 0,
    removed = #lines,
  }

  return { hunk }
end

GitClient.show = loop.promisify(function(self, tracked_filename, commit_hash, spec, callback)
  local err = {}
  local result = {}
  commit_hash = commit_hash or ''

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'show',
      -- git will attach self.cwd to the command which means we are going to search
      -- from the current relative path "./" basically just means "${self.cwd}/".
      string.format('%s:./%s', commit_hash, tracked_filename),
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      callback(nil, result)
    end,
  }, spec)):start()
end, 5)

GitClient.is_in_remote = loop.promisify(function(self, tracked_filename, commit_hash, spec, callback)
  commit_hash = commit_hash or 'HEAD'
  local err = false

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'show',
      -- git will attach self.cwd to the command which means we are going to search
      -- from the current relative path "./" basically just means "${self.cwd}/".
      string.format('%s:./%s', commit_hash, tracked_filename),
    }),
    on_stderr = function(line)
      if line then
        err = true
      end
    end,
    on_exit = function() callback(not err) end,
  }, spec)):start()
end, 5)

GitClient.stage = loop.promisify(function(self, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'add',
      '.',
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }, spec)):start()
end, 3)

GitClient.unstage = loop.promisify(function(self, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'reset',
      '-q',
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }, spec)):start()
end, 3)

GitClient.stage_file = loop.promisify(function(self, filename, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'add',
      '--',
      filename,
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
  }, spec)):start()
end, 4)

GitClient.unstage_file = loop.promisify(function(self, filename, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'reset',
      '-q',
      'HEAD',
      '--',
      filename,
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
  }, spec)):start()
end, 4)

GitClient.stage_hunk_from_patch = loop.promisify(function(self, patch_filename, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
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
  }, spec)):start()
end, 4)

GitClient.unstage_hunk_from_patch = loop.promisify(function(self, patch_filename, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
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
  }, spec)):start()
end, 4)

GitClient.is_ignored = loop.promisify(function(self, filename, spec, callback)
  filename = fs.make_relative(filename, self.cwd)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'check-ignore',
      filename,
    }),
    on_stdout = function(line) err[#err + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(true)
      end

      callback(false)
    end,
  }, spec)):start()
end, 4)

-- Only clears a tracked file.
GitClient.reset = loop.promisify(function(self, filename, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'checkout',
      '-q',
      '--',
      filename,
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }, spec)):start()
end, 4)

GitClient.reset_all = loop.promisify(function(self, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'checkout',
      '-q',
      '--',
      '.',
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }, spec)):start()
end, 3)

-- Only clears an untracked file.
GitClient.clean = loop.promisify(function(self, filename, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'clean',
      '-fd',
      '--',
      filename,
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }, spec)):start()
end, 4)

GitClient.clean_all = loop.promisify(function(self, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'clean',
      '-fd',
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil)
    end,
  }, spec)):start()
end, 3)

GitClient.current_branch = loop.promisify(function(self, spec, callback)
  local err = {}
  local result = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'branch',
      '--show-current',
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, result)
      end

      callback(nil, result)
    end,
  }, spec)):start()
end, 3)

GitClient.tracked_filename = loop.promisify(function(self, filename, commit_hash, spec, callback)
  filename = fs.make_relative(filename, self.cwd)
  local result = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'ls-files',
      '--exclude-standard',
      commit_hash or 'HEAD',
      filename,
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_exit = function() callback(result[1]) end,
  }, spec)):start()
end, 5)

GitClient.tracked_full_filename = loop.promisify(function(self, filename, spec, callback)
  filename = fs.make_relative(filename, self.cwd)
  local result = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'ls-files',
      '--exclude-standard',
      '--full-name',
      filename,
    }),
    on_stdout = function(line) result[#result + 1] = line end,
    on_exit = function() callback(result[1]) end,
  }, spec)):start()
end, 4)

GitClient.file_status = loop.promisify(function(self, tracked_filename, spec, callback)
  local err = {}
  local status = nil

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'status',
      '-u',
      '-s',
      '--no-renames',
      '--ignore-submodules',
      '--',
      tracked_filename,
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
        return callback(err, status)
      end

      callback(nil, status)
    end,
  }, spec)):start()
end, 4)

GitClient.status = loop.promisify(function(self, spec, callback)
  local err = {}
  local result = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'status',
      '-u',
      '-s',
      '--no-renames',
      '--ignore-submodules',
    }),
    on_stdout = function(line)
      local filename = line:sub(4, #line)

      if fs.is_dir(filename) then
        return
      end

      result[#result + 1] = GitBlob(line:sub(4, #line), Status(line:sub(1, 2)))
    end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, result)
      end

      callback(nil, result)
    end,
  }, spec)):start()
end, 3)

GitClient.ls_log = loop.promisify(function(self, log, spec, callback)
  local err = {}
  local result = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'diff-tree',
      '--no-commit-id',
      '--name-only',
      '-r',
      log.commit_hash,
      log.parent_hash == '' and self.empty_tree_hash or log.parent_hash,
    }),
    on_stdout = function(line) result[#result + 1] = GitBlob(line, Status('--'), log) end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, result)
      end

      callback(nil, result)
    end,
  }, spec)):start()
end, 4)

GitClient.ls_stash = loop.promisify(function(self, spec, callback)
  local err = {}
  local logs = {}
  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'stash',
      'list',
      '--color=never',
      '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
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
  }, spec)):start()
end, 3)

GitClient.checkout = loop.promisify(function(self, options, spec, callback)
  local err = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'checkout',
      '--quiet',
    }, options),
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function() return callback(#err ~= 0 and err or nil) end,
  }, spec)):start()
end, 4)

return GitClient
