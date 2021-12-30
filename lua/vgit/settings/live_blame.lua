local Config = require('vgit.core.Config')

return Config:new({
  enabled = true,
  format = function(blame, git_config)
    local config_author = git_config['user.name']
    local author = blame.author
    if config_author == author then
      author = 'You'
    end
    local time = os.difftime(os.time(), blame.author_time)
      / (60 * 60 * 24 * 30 * 12 * 1)
    local time_divisions = {
      { 1, 'years' },
      { 12, 'months' },
      { 30, 'days' },
      { 24, 'hours' },
      { 60, 'minutes' },
      { 60, 'seconds' },
    }
    local counter = 1
    local time_division = time_divisions[counter]
    local time_boundary = time_division[1]
    local time_postfix = time_division[2]
    while time < 1 and counter ~= #time_divisions do
      time_division = time_divisions[counter]
      time_boundary = time_division[1]
      time_postfix = time_division[2]
      time = time * time_boundary
      counter = counter + 1
    end
    local commit_message = blame.commit_message
    if not blame.committed then
      author = 'You'
      commit_message = 'Uncommitted changes'
      return string.format(' %s • %s', author, commit_message)
    end
    local max_commit_message_length = 255
    if #commit_message > max_commit_message_length then
      commit_message = commit_message:sub(1, max_commit_message_length) .. '...'
    end
    return string.format(
      ' %s, %s • %s',
      author,
      string.format(
        '%s %s ago',
        time >= 0 and math.floor(time + 0.5) or math.ceil(time - 0.5),
        time <= 1 and time_postfix:sub(1, #time_postfix - 1) or time_postfix
      ),
      commit_message
    )
  end,
})
