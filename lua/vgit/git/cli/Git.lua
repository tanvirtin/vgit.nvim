local fs = require('vgit.core.fs')
local Status = require('vgit.git.cli.models.Status')
local utils = require('vgit.core.utils')
local GitReadStream = require('vgit.git.GitReadStream')
local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local Hunk = require('vgit.git.cli.models.Hunk')
local Log = require('vgit.git.cli.models.Log')
local File = require('vgit.git.cli.models.File')
local Blame = require('vgit.git.cli.models.Blame')
local git_setting = require('vgit.settings.git')

local Git = Object:extend()

function Git:constructor(cwd)
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

function Git:set_cwd(cwd) self.cwd = cwd end

Git.is_commit_valid = loop.suspend(function(self, commit, spec, callback)
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

Git.config = loop.suspend(function(self, spec, callback)
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

Git.has_commits = loop.suspend(function(self, spec, callback)
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

Git.get_git_dir = loop.suspend(function(self, spec, callback)
  local err = {}
  local lines = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'rev-parse',
      '--absolute-git-dir',
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_stdout = function(line) lines[#lines + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end

      callback(nil, lines[1])
    end,
  }, spec)):start()
end, 3)

Git.is_inside_git_dir = loop.suspend(function(self, spec, callback)
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

Git.blames = loop.suspend(function(self, filename, spec, callback)
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

Git.blame_line = loop.suspend(function(self, filename, lnum, spec, callback)
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

Git.log = loop.suspend(function(self, commit_hash, spec, callback)
  local err = {}
  local logs = {}
  local revision_count = 0

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
      revision_count = revision_count + 1
      local log = Log(line, revision_count)

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

Git.logs = loop.suspend(function(self, options, spec, callback)
  local err = {}
  local logs = {}
  local revision_count = 0
  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      '--no-pager',
      'log',
      '--color=never',
      '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
    }, options),
    on_stdout = function(line)
      revision_count = revision_count + 1
      local log = Log(line, revision_count)

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

Git.file_logs = loop.suspend(function(self, filename, spec, callback)
  local err = {}
  local logs = {}
  local revision_count = 0
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
      revision_count = revision_count + 1
      local log = Log(line, revision_count)

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

Git.file_hunks = loop.suspend(function(self, filename_a, filename_b, spec, callback)
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

Git.index_hunks = loop.suspend(function(self, filename, spec, callback)
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

Git.remote_hunks = loop.suspend(function(self, filename, parent_hash, commit_hash, spec, callback)
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

Git.unmerged_hunks = loop.suspend(function(self, filename, stage_a, stage_b, spec, callback)
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
    string.format('%s:%s', stage_a, filename),
    string.format('%s:%s', stage_b, filename),
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
end, 6)

Git.staged_hunks = loop.suspend(function(self, filename, spec, callback)
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

function Git:untracked_hunks(lines)
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

function Git:deleted_hunks(lines)
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

Git.show = loop.suspend(function(self, tracked_filename, commit_hash, spec, callback)
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

Git.is_in_remote = loop.suspend(function(self, tracked_filename, commit_hash, spec, callback)
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

Git.stage = loop.suspend(function(self, spec, callback)
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

Git.unstage = loop.suspend(function(self, spec, callback)
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

Git.stage_file = loop.suspend(function(self, filename, spec, callback)
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

Git.unstage_file = loop.suspend(function(self, filename, spec, callback)
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

Git.stage_hunk_from_patch = loop.suspend(function(self, patch_filename, spec, callback)
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

Git.unstage_hunk_from_patch = loop.suspend(function(self, patch_filename, spec, callback)
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

Git.is_ignored = loop.suspend(function(self, filename, spec, callback)
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
Git.reset = loop.suspend(function(self, filename, spec, callback)
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

Git.reset_all = loop.suspend(function(self, spec, callback)
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
Git.clean = loop.suspend(function(self, filename, spec, callback)
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

Git.clean_all = loop.suspend(function(self, spec, callback)
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

Git.current_branch = loop.suspend(function(self, spec, callback)
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

Git.tracked_filename = loop.suspend(function(self, filename, commit_hash, spec, callback)
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

Git.tracked_full_filename = loop.suspend(function(self, filename, spec, callback)
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

Git.file_status = loop.suspend(function(self, tracked_filename, spec, callback)
  local err = {}
  local file = nil

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

      file = File(line:sub(4, #line), Status(line:sub(1, 2)))
    end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, file)
      end

      callback(nil, file)
    end,
  }, spec)):start()
end, 4)

Git.status = loop.suspend(function(self, spec, callback)
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

      result[#result + 1] = File(line:sub(4, #line), Status(line:sub(1, 2)))
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

Git.ls_log = loop.suspend(function(self, log, spec, callback)
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
    on_stdout = function(line) result[#result + 1] = File(line, Status('--'), log) end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, result)
      end

      callback(nil, result)
    end,
  }, spec)):start()
end, 4)

Git.ls_stash = loop.suspend(function(self, spec, callback)
  local err = {}
  local logs = {}
  local revision_count = 0
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
      revision_count = revision_count + 1
      local log = Log(line, revision_count)

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

Git.checkout = loop.suspend(function(self, options, spec, callback)
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

Git.commit = loop.suspend(function(self, msg, spec, callback)
  local err = {}
  local is_uncommitted = false
  local has_no_changes = false

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'commit',
      '-m',
      msg,
    }),
    on_stderr = function(line) err[#err + 1] = line end,
    on_stdout = function(line)
      if vim.startswith(line, 'no changes added to commit') then
        is_uncommitted = true
      end
      if vim.startswith(line, 'nothing to commit, working tree clean') then
        has_no_changes = true
      end
    end,
    on_exit = function()
      if has_no_changes then
        return callback({ 'Nothing to commit, working tree clean' }, nil)
      end

      if is_uncommitted then
        return callback({ 'No changes added to commit (use "git add" and/or "git commit -a")' }, nil)
      end

      if #err ~= 0 then
        return callback(err, nil)
      end

      callback()
    end,
  }, spec)):start()
end, 4)

Git.get_commit = loop.suspend(function(self, spec, callback)
  local err = {}
  local lines = {}

  GitReadStream(utils.object.defaults({
    command = self.cmd,
    args = utils.list.merge(self.fallback_args, {
      '-C',
      self.cwd,
      'commit',
      '--dry-run',
    }),
    on_stdout = function(line) lines[#lines + 1] = line end,
    on_stderr = function(line) err[#err + 1] = line end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end

      callback(nil, lines)
    end,
  }, spec)):start()
end, 3)

return Git
