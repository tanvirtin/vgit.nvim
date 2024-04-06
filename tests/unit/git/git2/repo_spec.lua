local repo = require('vgit.git.git2.repo')
local async = require('plenary.async.tests')

local eq = assert.are.same

async.describe('repo:', function()
    async.it('should be able to retrieve current repo path', function()
      local repopath, err = repo.discover()
      assert(not err)
      eq(repopath, vim.loop.cwd())
    end)

    async.it('returns true if repo exists', function()
      local exists, err = repo.exists()
      assert(not err)
      eq(exists, true)
    end)

    async.it('should be able to discover a repository', function()
      local filepath = vim.loop.cwd() .. '/' .. 'README.md'
      local repopath, err = repo.discover(filepath)
      assert(not err)
      eq(repopath, vim.loop.cwd())
    end)

    async.it('should be true if a file exists in a repository', function()
      local filepath = vim.loop.cwd() .. '/' .. 'README.md'
      local exists, err = repo.exists(filepath)
      assert(not err)
      eq(exists, true)
    end)
end)
