local utils = require('vgit.utils')
local Job = require('vgit.Job')
local Hunk = require('vgit.Hunk')
local Interface = require('vgit.Interface')
local wrap = require('plenary.async.async').wrap
local void = require('plenary.async.async').void

local M = {}

M.constants = utils.readonly({
  diff_algorithm = 'myers',
  empty_tree_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904',
})

M.state = Interface:new({
  diff_base = 'HEAD',
  config = {},
})

M.get_diff_base = function()
  return M.state:get('diff_base')
end

M.set_diff_base = function(diff_base)
  M.state:set('diff_base', diff_base)
end

M.is_commit_valid = wrap(function(commit, callback)
  local result = {}
  local err = {}
  local job = Job:new({
    command = 'git',
    args = {
      'show',
      '--abbrev-commit',
      '--oneline',
      '--no-notes',
      '--no-patch',
      '--no-color',
      commit,
    },
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
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
  })
  job:start()
end, 2)

M.create_log = function(line, revision_count)
  local log = vim.split(line, '-')
  -- Sometimes you can have multiple parents, in that instance we pick the first!
  local parents = vim.split(log[2], ' ')
  if #parents > 1 then
    log[2] = parents[1]
  end
  return {
    revision = string.format('HEAD~%s', revision_count),
    commit_hash = log[1]:sub(2, #log[1]),
    parent_hash = log[2],
    timestamp = log[3],
    author_name = log[4],
    author_email = log[5],
    summary = log[6]:sub(1, #log[6] - 1),
  }
end

M.create_blame = function(info)
  local function split_by_whitespace(str)
    return vim.split(str, ' ')
  end
  local commit_hash_info = split_by_whitespace(info[1])
  local author_mail_info = split_by_whitespace(info[3])
  local author_time_info = split_by_whitespace(info[4])
  local author_tz_info = split_by_whitespace(info[5])
  local committer_mail_info = split_by_whitespace(info[7])
  local committer_time_info = split_by_whitespace(info[8])
  local committer_tz_info = split_by_whitespace(info[9])
  local parent_hash_info = split_by_whitespace(info[11])
  local author = info[2]:sub(8, #info[2])
  local author_mail = author_mail_info[2]
  local committer = info[6]:sub(11, #info[6])
  local committer_mail = committer_mail_info[2]
  local lnum = tonumber(commit_hash_info[3])
  local committed = true
  if
    author == 'Not Committed Yet'
    and committer == 'Not Committed Yet'
    and author_mail == '<not.committed.yet>'
    and committer_mail == '<not.committed.yet>'
  then
    committed = false
  end
  return {
    lnum = lnum,
    commit_hash = commit_hash_info[1],
    parent_hash = parent_hash_info[2],
    author = author,
    author_mail = (function()
      local mail = author_mail
      if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
        mail = mail:sub(2, #mail - 1)
      end
      return mail
    end)(),
    author_time = tonumber(author_time_info[2]),
    author_tz = author_tz_info[2],
    committer = committer,
    committer_mail = (function()
      local mail = committer_mail
      if mail:sub(1, 1) == '<' and mail:sub(#mail, #mail) then
        mail = mail:sub(2, #mail - 1)
      end
      return mail
    end)(),
    committer_time = tonumber(committer_time_info[2]),
    committer_tz = committer_tz_info[2],
    commit_message = info[10]:sub(9, #info[10]),
    committed = committed,
  }
end

-- TODO: This needs to be removed.
M.setup = void(function(config)
  M.state:assign(config)
  local err, git_config = M.config()
  if not err then
    M.state:set('config', git_config)
  end
end)

M.config = wrap(function(callback)
  local err = {}
  local result = {}
  local job = Job:new({
    command = 'git',
    args = {
      'config',
      '--list',
    },
    on_stdout = function(_, line)
      local line_chunks = vim.split(line, '=')
      result[line_chunks[1]] = line_chunks[2]
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end
      callback(nil, result)
    end,
  })
  job:start()
end, 1)

M.has_commits = wrap(function(callback)
  local result = true
  local job = Job:new({
    command = 'git',
    args = { 'status' },
    on_stdout = function(_, line)
      if line == 'No commits yet' then
        result = false
      end
    end,
    on_exit = function()
      callback(result)
    end,
  })
  job:start()
end, 1)

M.is_inside_work_tree = wrap(function(callback)
  local err = {}
  local job = Job:new({
    command = 'git',
    args = {
      'rev-parse',
      '--is-inside-work-tree',
    },
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(false)
      end
      callback(true)
    end,
  })
  job:start()
end, 1)

M.blames = wrap(function(filename, callback)
  local err = {}
  local result = {}
  local blame_info = {}
  local job = Job:new({
    command = 'git',
    args = {
      'blame',
      '--line-porcelain',
      '--',
      filename,
    },
    on_stdout = function(_, data, _)
      if string.byte(data:sub(1, 3)) ~= 9 then
        table.insert(blame_info, data)
      else
        local blame = M.create_blame(blame_info)
        if blame then
          result[#result + 1] = blame
        end
        blame_info = {}
      end
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end
      callback(nil, result)
    end,
  })
  job:start()
end, 2)

M.blame_line = wrap(function(filename, lnum, callback)
  local err = {}
  local result = {}
  local job = Job:new({
    command = 'git',
    args = {
      'blame',
      '-L',
      string.format('%s,+1', lnum),
      '--line-porcelain',
      '--',
      filename,
    },
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end
      callback(nil, M.create_blame(result))
    end,
  })
  job:start()
end, 3)

M.logs = wrap(function(filename, callback)
  local err = {}
  local logs = {}
  local revision_count = 0
  local job = Job:new({
    command = 'git',
    args = {
      'log',
      '--color=never',
      '--pretty=format:"%H-%P-%at-%an-%ae-%s"',
      '--',
      filename,
    },
    on_stdout = function(_, data, _)
      revision_count = revision_count + 1
      local log = M.create_log(data, revision_count)
      if log then
        logs[#logs + 1] = log
      end
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end
      return callback(nil, logs)
    end,
  })
  job:start()
end, 2)

M.file_hunks = wrap(function(filename_a, filename_b, callback)
  local result = {}
  local err = {}
  local args = {
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--no-index',
    filename_a,
    filename_b,
  }
  local job = Job:new({
    command = 'git',
    args = args,
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
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
            hunk.diff[#hunk.diff + 1] = line
          end
        end
      end
      return callback(nil, hunks)
    end,
  })
  job:start()
end, 3)

M.index_hunks = wrap(function(filename, callback)
  local result = {}
  local err = {}
  local args = {
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--',
    filename,
  }
  local job = Job:new({
    command = 'git',
    args = args,
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
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
            hunk.diff[#hunk.diff + 1] = line
          end
        end
      end
      return callback(nil, hunks)
    end,
  })
  job:start()
end, 2)

M.remote_hunks = wrap(function(filename, parent_hash, commit_hash, callback)
  local result = {}
  local err = {}
  local args = {
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
    M.state:get('diff_base'),
    '--',
    filename,
  }
  if parent_hash and not commit_hash then
    args = {
      '--no-pager',
      '-c',
      'core.safecrlf=false',
      'diff',
      '--color=never',
      string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
      '--patch-with-raw',
      '--unified=0',
      parent_hash,
      '--',
      filename,
    }
  end
  if parent_hash and commit_hash then
    args = {
      '--no-pager',
      '-c',
      'core.safecrlf=false',
      'diff',
      '--color=never',
      string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
      '--patch-with-raw',
      '--unified=0',
      #parent_hash > 0 and parent_hash or M.constants.empty_tree_hash,
      commit_hash,
      '--',
      filename,
    }
  end
  local job = Job:new({
    command = 'git',
    args = args,
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
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
            hunk.diff[#hunk.diff + 1] = line
          end
        end
      end
      return callback(nil, hunks)
    end,
  })
  job:start()
end, 4)

M.staged_hunks = wrap(function(filename, callback)
  local result = {}
  local err = {}
  local args = {
    '--no-pager',
    '-c',
    'core.safecrlf=false',
    'diff',
    '--color=never',
    string.format('--diff-algorithm=%s', M.constants.diff_algorithm),
    '--patch-with-raw',
    '--unified=0',
    '--cached',
    '--',
    filename,
  }
  local job = Job:new({
    command = 'git',
    args = args,
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
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
            hunk.diff[#hunk.diff + 1] = line
          end
        end
      end
      return callback(nil, hunks)
    end,
  })
  job:start()
end, 2)

M.untracked_hunks = function(lines)
  local diff = {}
  for i = 1, #lines do
    diff[#diff + 1] = string.format('+%s', lines[i])
  end
  return {
    {
      header = nil,
      start = 1,
      finish = #lines,
      type = 'add',
      diff = diff,
    },
  }
end

M.show = wrap(function(filename, commit_hash, callback)
  local err = {}
  local result = {}
  commit_hash = commit_hash or ''
  local job = Job:new({
    command = 'git',
    args = {
      'show',
      string.format('%s:%s', commit_hash, filename),
    },
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, nil)
      end
      callback(nil, result)
    end,
  })
  job:start()
end, 3)

M.stage_file = wrap(function(filename, callback)
  local err = {}
  local job = Job:new({
    command = 'git',
    args = {
      'add',
      filename,
    },
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end
      callback(nil)
    end,
  })
  job:start()
end, 2)

M.unstage_file = wrap(function(filename, callback)
  local err = {}
  local job = Job:new({
    command = 'git',
    args = {
      'reset',
      '-q',
      'HEAD',
      '--',
      filename,
    },
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end
      callback(nil)
    end,
  })
  job:start()
end, 2)

M.stage_hunk_from_patch = wrap(function(patch_filename, callback)
  local err = {}
  local job = Job:new({
    command = 'git',
    args = {
      'apply',
      '--cached',
      '--whitespace=nowarn',
      '--unidiff-zero',
      patch_filename,
    },
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end
      callback(nil)
    end,
  })
  job:start()
end, 2)

M.check_ignored = wrap(function(filename, callback)
  local err = {}
  local job = Job:new({
    command = 'git',
    args = {
      'check-ignore',
      filename,
    },
    on_stdout = function(_, data, _)
      err[#err + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(true)
      end
      callback(false)
    end,
  })
  job:start()
end, 2)

M.reset = wrap(function(filename, callback)
  local err = {}
  local job = Job:new({
    command = 'git',
    args = {
      'checkout',
      '-q',
      '--',
      filename,
    },
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err)
      end
      callback(nil)
    end,
  })
  job:start()
end, 2)

M.current_branch = wrap(function(callback)
  local err = {}
  local result = {}
  local job = Job:new({
    command = 'git',
    args = {
      'branch',
      '--show-current',
    },
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, result)
      end
      callback(nil, result)
    end,
  })
  job:start()
end, 1)

M.tracked_filename = wrap(function(filename, callback)
  local result = {}
  local job = Job:new({
    command = 'git',
    args = {
      'ls-files',
      '--exclude-standard',
      filename,
    },
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_exit = function()
      callback(result[1])
    end,
  })
  job:start()
end, 2)

M.tracked_remote_filename = wrap(function(filename, callback)
  local result = {}
  local job = Job:new({
    command = 'git',
    args = {
      'ls-files',
      '--exclude-standard',
      '--full-name',
      filename,
    },
    on_stdout = function(_, data, _)
      result[#result + 1] = data
    end,
    on_exit = function()
      callback(result[1])
    end,
  })
  job:start()
end, 2)

M.ls_changed = wrap(function(callback)
  local err = {}
  local result = {}
  local job = Job:new({
    command = 'git',
    args = {
      'status',
      '-u',
      '-s',
      '--',
      '.',
    },
    on_stdout = function(_, data, _)
      result[#result + 1] = {
        filename = data:sub(4, #data),
        status = data:sub(1, 2),
      }
    end,
    on_stderr = function(_, data, _)
      err[#err + 1] = data
    end,
    on_exit = function()
      if #err ~= 0 then
        return callback(err, result)
      end
      callback(nil, result)
    end,
  })
  job:start()
end, 1)

return M
