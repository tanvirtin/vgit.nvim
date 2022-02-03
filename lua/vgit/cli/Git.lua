local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local Job = require('vgit.core.Job')
local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local Hunk = require('vgit.cli.models.Hunk')
local Log = require('vgit.cli.models.Log')
local File = require('vgit.cli.models.File')
local Blame = require('vgit.cli.models.Blame')

-- TODO: Expensive jobs can be run in the background by leveraging coroutines.
-- The decision to make a job run in background cannot be controlled, which needs to changed.

local Git = Object:extend()

function Git:new(cwd)
  return setmetatable({
    cwd = cwd or '',
    diff_algorithm = 'myers',
    empty_tree_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904',
    state = {
      config = nil,
    },
  }, Git)
end

function Git:set_cwd(cwd)
  self.cwd = cwd
end

Git.is_commit_valid = loop.promisify(function(self, commit, spec, callback)
  local result = {}
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'show',
        '--abbrev-commit',
        '--oneline',
        '--no-notes',
        '--no-patch',
        '--no-color',
        commit,
      },
      on_stdout = function(line)
        result[#result + 1] = line
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(false)
        end
        if #result == 0 then
          return callback(false)
        end
        callback(true)
      end,
    }, spec))
    :start()
end, 4)

Git.config = loop.promisify(function(self, spec, callback)
  if self.state.config then
    return callback(nil, self.state.config)
  end
  local err = {}
  local result = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'config',
        '--list',
      },
      on_stdout = function(line)
        local line_chunks = vim.split(line, '=')
        result[line_chunks[1]] = line_chunks[2]
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, nil)
        end
        self.state.config = result
        callback(nil, result)
      end,
    }, spec))
    :start()
end, 3)

Git.has_commits = loop.promisify(function(self, spec, callback)
  local result = true
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'status',
      },
      on_stdout = function(line)
        if line == 'No commits yet' then
          result = false
        end
      end,
      on_exit = function()
        callback(result)
      end,
    }, spec))
    :start()
end, 3)

Git.is_inside_git_dir = loop.promisify(function(self, spec, callback)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'rev-parse',
        '--is-inside-git-dir',
      },
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(false)
        end
        callback(true)
      end,
    }, spec))
    :start()
end, 3)

Git.blames = loop.promisify(function(self, filename, spec, callback)
  local err = {}
  local result = {}
  local blame_info = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'blame',
        '--line-porcelain',
        '--',
        filename,
      },
      on_stdout = function(line)
        if string.byte(line:sub(1, 3)) ~= 9 then
          table.insert(blame_info, line)
        else
          local blame = Blame:new(blame_info)
          if blame then
            result[#result + 1] = blame
          end
          blame_info = {}
        end
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, nil)
        end
        callback(nil, result)
      end,
    }, spec))
    :start()
end, 4)

Git.blame_line = loop.promisify(function(self, filename, lnum, spec, callback)
  filename = utils.str.strip(filename, self.cwd)
  local err = {}
  local result = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'blame',
        '-L',
        string.format('%s,+1', lnum),
        '--line-porcelain',
        '--',
        filename,
      },
      on_stdout = function(line)
        result[#result + 1] = line
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, nil)
        end
        callback(nil, Blame:new(result))
      end,
    }, spec))
    :start()
end, 5)

Git.logs = loop.promisify(function(self, filename, spec, callback)
  local err = {}
  local logs = {}
  local revision_count = 0
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'log',
        '--color=never',
        '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
        '--',
        filename,
      },
      on_stdout = function(line)
        revision_count = revision_count + 1
        local log = Log:new(line, revision_count)
        if log then
          logs[#logs + 1] = log
        end
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, nil)
        end
        return callback(nil, logs)
      end,
    }, spec))
    :start()
end, 4)

Git.file_hunks = loop.promisify(
  function(self, filename_a, filename_b, spec, callback)
    local result = {}
    local err = {}
    local args = {
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
    }
    Job
      :new(utils.object.defaults({
        command = 'git',
        args = args,
        on_stdout = function(line)
          result[#result + 1] = line
        end,
        on_stderr = function(line)
          err[#err + 1] = line
        end,
        on_exit = function()
          if #err ~= 0 then
            return callback(err, nil)
          end
          local hunks = {}
          for i = 1, #result do
            local line = result[i]
            if vim.startswith(line, '@@') then
              hunks[#hunks + 1] = Hunk:new(line)
            else
              if #hunks > 0 then
                local hunk = hunks[#hunks]
                hunk:append_diff_line(line)
              end
            end
          end
          return callback(nil, hunks)
        end,
      }, spec))
      :start()
  end,
  5
)

Git.index_hunks = loop.promisify(function(self, filename, spec, callback)
  local result = {}
  local err = {}
  local args = {
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
  }
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = args,
      on_stdout = function(line)
        result[#result + 1] = line
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, nil)
        end
        local hunks = {}
        for i = 1, #result do
          local line = result[i]
          if vim.startswith(line, '@@') then
            hunks[#hunks + 1] = Hunk:new(line)
          else
            if #hunks > 0 then
              local hunk = hunks[#hunks]
              hunk:append_diff_line(line)
            end
          end
        end
        return callback(nil, hunks)
      end,
    }, spec))
    :start()
end, 4)

Git.remote_hunks = loop.promisify(
  function(self, filename, parent_hash, commit_hash, spec, callback)
    local result = {}
    local err = {}
    local args = {
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
    }
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
    Job
      :new(utils.object.defaults({
        command = 'git',
        args = args,
        on_stdout = function(line)
          result[#result + 1] = line
        end,
        on_stderr = function(line)
          err[#err + 1] = line
        end,
        on_exit = function()
          if #err ~= 0 then
            return callback(err, nil)
          end
          local hunks = {}
          for i = 1, #result do
            local line = result[i]
            if vim.startswith(line, '@@') then
              hunks[#hunks + 1] = Hunk:new(line)
            else
              if #hunks > 0 then
                local hunk = hunks[#hunks]
                hunk:append_diff_line(line)
              end
            end
          end
          return callback(nil, hunks)
        end,
      }, spec))
      :start()
  end,
  6
)

Git.staged_hunks = loop.promisify(function(self, filename, spec, callback)
  local result = {}
  local err = {}
  local args = {
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
  }
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = args,
      on_stdout = function(line)
        result[#result + 1] = line
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, nil)
        end
        local hunks = {}
        for i = 1, #result do
          local line = result[i]
          if vim.startswith(line, '@@') then
            hunks[#hunks + 1] = Hunk:new(line)
          else
            if #hunks > 0 then
              local hunk = hunks[#hunks]
              hunk:append_diff_line(line)
            end
          end
        end
        return callback(nil, hunks)
      end,
    }, spec))
    :start()
end, 4)

function Git:untracked_hunks(lines)
  local diff = {}
  for i = 1, #lines do
    diff[#diff + 1] = string.format('+%s', lines[i])
  end
  local hunk = Hunk:new()
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
  local hunk = Hunk:new()
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

Git.show = loop.promisify(
  function(self, tracked_filename, commit_hash, spec, callback)
    local err = {}
    local result = {}
    commit_hash = commit_hash or ''
    Job
      :new(utils.object.defaults({
        command = 'git',
        args = {
          '-C',
          self.cwd,
          'show',
          -- git will attach self.cwd to the command which means we are going to search
          -- from the current relative path "./" basically just means "${self.cwd}/".
          string.format('%s:./%s', commit_hash, tracked_filename),
        },
        on_stdout = function(line)
          result[#result + 1] = line
        end,
        on_stderr = function(line)
          err[#err + 1] = line
        end,
        on_exit = function()
          if #err ~= 0 then
            return callback(err, nil)
          end
          callback(nil, result)
        end,
      }, spec))
      :start()
  end,
  5
)

Git.is_in_remote = loop.promisify(
  function(self, tracked_filename, spec, callback)
    local err = false
    Job
      :new(utils.object.defaults({
        command = 'git',
        args = {
          '-C',
          self.cwd,
          'show',
          -- git will attach self.cwd to the command which means we are going to search
          -- from the current relative path "./" basically just means "${self.cwd}/".
          string.format('HEAD:./%s', tracked_filename),
        },
        on_stderr = function(line)
          if line then
            err = true
          end
        end,
        on_exit = function()
          callback(not err)
        end,
      }, spec))
      :start()
  end,
  4
)

Git.stage = loop.promisify(function(self, spec, callback)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'add',
        '.',
      },
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err)
        end
        callback(nil)
      end,
    }, spec))
    :start()
end, 3)

Git.unstage = loop.promisify(function(self, spec, callback)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'reset',
        '-q',
        'HEAD',
        '.',
      },
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err)
        end
        callback(nil)
      end,
    }, spec))
    :start()
end, 3)

Git.stage_file = loop.promisify(function(self, filename, spec, callback)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'add',
        filename,
      },
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err)
        end
        callback(nil)
      end,
    }, spec))
    :start()
end, 4)

Git.unstage_file = loop.promisify(function(self, filename, spec, callback)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'reset',
        '-q',
        'HEAD',
        '--',
        filename,
      },
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err)
        end
        callback(nil)
      end,
    }, spec))
    :start()
end, 4)

Git.stage_hunk_from_patch = loop.promisify(
  function(self, patch_filename, spec, callback)
    local err = {}
    Job
      :new(utils.object.defaults({
        command = 'git',
        args = {
          '-C',
          self.cwd,
          'apply',
          '--cached',
          '--whitespace=nowarn',
          '--unidiff-zero',
          patch_filename,
        },
        on_stderr = function(line)
          err[#err + 1] = line
        end,
        on_exit = function()
          if #err ~= 0 then
            return callback(err)
          end
          callback(nil)
        end,
      }, spec))
      :start()
  end,
  4
)

Git.is_ignored = loop.promisify(function(self, filename, spec, callback)
  filename = utils.str.strip(filename, self.cwd)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'check-ignore',
        filename,
      },
      on_stdout = function(line)
        err[#err + 1] = line
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(true)
        end
        callback(false)
      end,
    }, spec))
    :start()
end, 4)

Git.reset = loop.promisify(function(self, filename, spec, callback)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'checkout',
        '-q',
        '--',
        filename,
      },
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err)
        end
        callback(nil)
      end,
    }, spec))
    :start()
end, 4)

Git.discard = loop.promisify(function(self, spec, callback)
  local err = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'checkout',
        '-q',
        '--',
        '.',
      },
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err)
        end
        callback(nil)
      end,
    }, spec))
    :start()
end, 3)

Git.current_branch = loop.promisify(function(self, spec, callback)
  local err = {}
  local result = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'branch',
        '--show-current',
      },
      on_stdout = function(line)
        result[#result + 1] = line
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, result)
        end
        callback(nil, result)
      end,
    }, spec))
    :start()
end, 3)

Git.tracked_filename = loop.promisify(function(self, filename, spec, callback)
  filename = utils.str.strip(filename, self.cwd)
  local result = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'ls-files',
        '--exclude-standard',
        filename,
      },
      on_stdout = function(line)
        result[#result + 1] = line
      end,
      on_exit = function()
        callback(result[1])
      end,
    }, spec))
    :start()
end, 4)

Git.tracked_full_filename = loop.promisify(
  function(self, filename, spec, callback)
    filename = utils.str.strip(filename, self.cwd)
    local result = {}
    Job
      :new(utils.object.defaults({
        command = 'git',
        args = {
          '-C',
          self.cwd,
          'ls-files',
          '--exclude-standard',
          '--full-name',
          filename,
        },
        on_stdout = function(line)
          result[#result + 1] = line
        end,
        on_exit = function()
          callback(result[1])
        end,
      }, spec))
      :start()
  end,
  4
)

Git.status = loop.promisify(function(self, spec, callback)
  local err = {}
  local result = {}
  Job
    :new(utils.object.defaults({
      command = 'git',
      args = {
        '-C',
        self.cwd,
        'status',
        '-u',
        '-s',
        '--no-renames',
        '--ignore-submodules',
      },
      on_stdout = function(line)
        local filename = line:sub(4, #line)
        if fs.is_dir(filename) then
          return
        end
        result[#result + 1] = File:new(line)
      end,
      on_stderr = function(line)
        err[#err + 1] = line
      end,
      on_exit = function()
        if #err ~= 0 then
          return callback(err, result)
        end
        callback(nil, result)
      end,
    }, spec))
    :start()
end, 3)

return Git
