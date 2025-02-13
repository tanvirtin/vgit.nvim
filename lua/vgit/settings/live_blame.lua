local Config = require('vgit.core.Config')

return Config({
  enabled = true,
  debounce_ms = 200,
  format = function(blame, git_config)
    local config_author = git_config['user.name']
    local author = blame.author
    if config_author == author then author = 'You' end
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
    return string.format(' %s, %s • %s', author, blame:age().display, commit_message)
  end,
})
