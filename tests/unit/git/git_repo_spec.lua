local fs = require('vgit.core.fs')
local async = require('plenary.async.tests')
local git_repo = require('vgit.libgit2.git_repo')

local eq = assert.are.same

async.describe('repo:', function()
  async.it('should be able to retrieve current repo path', function()
    local repo, err = git_repo.discover()
    assert(not err)
    eq(repo, vim.loop.cwd())
  end)

  async.it('returns true if repo exists', function()
    local exists, err = git_repo.exists()
    assert(not err)
    eq(exists, true)
  end)

  async.it('should be able to discover a repository', function()
    local filepath = vim.loop.cwd() .. fs.sep .. 'README.md'
    local repo, err = git_repo.discover(filepath)
    assert(not err)
    eq(repo, vim.loop.cwd())
  end)

  async.it('should be true if a file exists in a repository', function()
    local filepath = vim.loop.cwd() .. fs.sep .. 'README.md'
    local exists, err = git_repo.exists(filepath)
    assert(not err)
    eq(exists, true)
  end)
end)
