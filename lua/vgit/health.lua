local health = {}

health.check = function()
  vim.health.start('Neovim version')
  local v = vim.version()
  local version_str = string.format('%d.%d.%d', v.major, v.minor, v.patch)
  if v.major == 0 and v.minor < 10 then
    vim.health.error('Neovim >= 0.10.0 is required, found ' .. version_str, { 'Upgrade Neovim to 0.10.0 or later' })
  else
    vim.health.ok('Neovim ' .. version_str)
  end

  vim.health.start('Git version')
  local git_setting = require('vgit.settings.git')
  local git_cmd = git_setting:get('cmd')
  if git_cmd ~= 'git' then vim.health.info('Git command: ' .. git_cmd) end
  if vim.fn.executable(git_cmd) == 0 then
    vim.health.error(git_cmd .. ' is not executable', { 'Install git or update the git cmd setting' })
  else
    local git_version_output = vim.fn.system({ git_cmd, '--version' })
    local git_version = git_version_output:match('git version (%S+)')
    if git_version then
      vim.health.info('Git version: ' .. git_version)
      local major, minor = git_version:match('^(%d+)%.(%d+)')
      major, minor = tonumber(major), tonumber(minor)
      if major and minor then
        if major < 2 or (major == 2 and minor < 18) then
          vim.health.warn(
            'Git >= 2.18.0 is recommended, found ' .. git_version,
            { 'Upgrade git to 2.18.0 or later for full functionality' }
          )
        else
          vim.health.ok('Git version is sufficient')
        end
      end
    else
      vim.health.warn('Could not parse git version from: ' .. git_version_output)
    end
  end

  vim.health.start('Git repository')
  local rev_parse_output = vim.fn.system({ git_cmd, 'rev-parse', '--is-inside-work-tree' })
  if vim.v.shell_error == 0 and rev_parse_output:match('true') then
    vim.health.ok('Inside a git repository')
  else
    vim.health.warn('Not inside a git repository', { 'vgit features require a git repository' })
  end

  vim.health.start('Plugin status')
  if vim.fn.exists(':VGit') == 2 then
    vim.health.ok('Plugin is set up')
  else
    vim.health.error('Plugin is not set up', { 'Call require(\'vgit\').setup() in your Neovim configuration' })
  end

  vim.health.start('Configuration')
  local live_blame_setting = require('vgit.settings.live_blame')
  local live_gutter_setting = require('vgit.settings.live_gutter')
  vim.health.info('Live blame: ' .. (live_blame_setting:get('enabled') and 'enabled' or 'disabled'))
  vim.health.info('Live gutter: ' .. (live_gutter_setting:get('enabled') and 'enabled' or 'disabled'))
  vim.health.info('Diff algorithm: ' .. git_setting:get('algorithm'))

  vim.health.start('Optional dependencies')
  local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
  if has_devicons and devicons.has_loaded() then
    vim.health.ok('nvim-web-devicons is available')
  else
    vim.health.info('nvim-web-devicons is not available (file icons will not be shown)')
  end

  local libgit2_setting = require('vgit.settings.libgit2')
  if not libgit2_setting:get('enabled') then
    vim.health.info('libgit2 integration is disabled')
  else
    local libgit2 = require('vgit.libgit2')
    local libgit2_path = libgit2_setting:get('path')
    vim.health.info('libgit2 path: ' .. libgit2_path)
    if libgit2_path == '' or vim.fn.filereadable(libgit2_path) == 0 then
      vim.health.error(
        'libgit2 library not found at: ' .. libgit2_path,
        { 'Set the correct path to libgit2.dylib/libgit2.so in your vgit configuration' }
      )
    elseif libgit2.initialized then
      vim.health.ok('libgit2 is loaded and initialized')
    else
      vim.health.error(
        'libgit2 is enabled but not initialized',
        { 'Ensure the libgit2 path points to a valid libgit2 shared library' }
      )
    end
  end
end

return health
