local utils = require('vgit.utils')
local Interface = require('vgit.Interface')

local M = {}

local virtual_line_nr_width = 6

M.state = Interface:new({
  layout = require('vgit.layouts.default'),
  preview = {
    indicator_hl = 'VGitIndicator',
    virtual_line_nr_width = virtual_line_nr_width,
    sign = {
      priority = 10,
      hls = {
        add = 'DiffAdd',
        remove = 'DiffDelete',
      },
    },
    symbols = {
      void = '⣿',
      indicator = '  ❯',
    },
  },
  sign = {
    priority = 10,
    hls = {
      add = 'VGitSignAdd',
      remove = 'VGitSignRemove',
      change = 'VGitSignChange',
    },
  },
  line_blame = {
    hl = 'Comment',
    format = function(blame, git_config)
      local config_author = git_config['user.name']
      local author = blame.author
      if config_author == author then
        author = 'You'
      end
      local time = os.difftime(os.time(), blame.author_time) / (24 * 60 * 60)
      local time_format = string.format('%s days ago', utils.round(time))
      local time_divisions = {
        { 24, 'hours' },
        { 60, 'minutes' },
        { 60, 'seconds' },
      }
      local division_counter = 1
      while time < 1 and division_counter ~= #time_divisions do
        local division = time_divisions[division_counter]
        time = time * division[1]
        time_format = string.format('%s %s ago', utils.round(time), division[2])
        division_counter = division_counter + 1
      end
      local commit_message = blame.commit_message
      if not blame.committed then
        author = 'You'
        commit_message = 'Uncommitted changes'
        local info = string.format('%s • %s', author, commit_message)
        return string.format(' %s', info)
      end
      local max_commit_message_length = 255
      if #commit_message > max_commit_message_length then
        commit_message = commit_message:sub(1, max_commit_message_length)
          .. '...'
      end
      local info = string.format(
        '%s, %s • %s',
        author,
        time_format,
        commit_message
      )
      return string.format(' %s', info)
    end,
  },
})

M.setup = function(config)
  config = config or {}
  M.state:assign(config.render)
end

M.get = function(key)
  return M.state:get(key)
end

M.set = function(key, value)
  return M.state:set(key, value)
end

return M
