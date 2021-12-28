local Buffer = require('vgit.core.Buffer')
local GitStore = require('vgit.GitStore')

local describe = describe
local it = it
local before_each = before_each
local eq = assert.are.same

describe('GitStore:', function()
  describe('new', function()
    it('should create an instance of the git store object', function()
      local git_store = GitStore:new()
      eq(git_store:is(GitStore), true)
    end)
  end)

  describe('add', function()
    local git_store
    local buffer
    before_each(function()
      git_store = GitStore:new()
      buffer = Buffer:new(1)
    end)
    it('should add a buffer inside git store', function()
      git_store:add(buffer)
      eq(git_store.buffers[buffer.bufnr], buffer)
    end)
  end)

  describe('remove', function()
    local git_store
    local buffer
    before_each(function()
      git_store = GitStore:new()
      buffer = Buffer:new(1)
      git_store:add(buffer)
    end)
    it('should remove a buffer', function()
      git_store:remove(buffer)
      eq(git_store.buffers[buffer.bufnr], nil)
    end)
  end)

  describe('current', function()
    local git_store
    local buffer
    before_each(function()
      git_store = GitStore:new()
      buffer = Buffer:new(0)
      git_store:add(buffer)
    end)
    it('should return the current buffer', function()
      eq(git_store:current(), buffer)
    end)
  end)

  describe('size', function()
    local git_store
    before_each(function()
      git_store = GitStore:new()
    end)
    it('should return the total number of buffers', function()
      eq(git_store:size(), 0)
      local size = 10
      for _ = 1, size do
        git_store:add(Buffer:new():create())
      end
      eq(git_store:size(), size)
    end)
  end)

  describe('is_empty', function()
    local git_store
    before_each(function()
      git_store = GitStore:new()
    end)
    it('should return false if the store is not empty', function()
      local size = 10
      for _ = 1, size do
        git_store:add(Buffer:new():create())
      end
      eq(git_store:is_empty(), false)
    end)
    it('should return true if the store is empty', function()
      eq(git_store:is_empty(), true)
    end)
  end)

  describe('clean', function()
    local size = 10
    local bufnrs = {}
    local git_store
    before_each(function()
      git_store = GitStore:new()
      bufnrs = {}
      for _ = 1, size do
        local bufnr = vim.api.nvim_create_buf(false, false)
        bufnrs[#bufnrs + 1] = bufnr
        git_store:add(Buffer:new(bufnr))
      end
    end)
    it('should clean any buffer that has been deleted from vim', function()
      for i = 1, size do
        local bufnr = bufnrs[i]
        local buffer = Buffer:new(bufnr)
        eq(git_store:contains(buffer), true)
        vim.api.nvim_buf_delete(bufnr, { force = true })
        git_store:clean()
        eq(git_store:contains(buffer), false)
      end
    end)

    it(
      'should invoke a callback per buffer removed if a callback is passed',
      function()
        for i = 1, size do
          local bufnr = bufnrs[i]
          local buffer = Buffer:new(bufnr)
          eq(git_store:contains(buffer), true)
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        local size_count = 0
        git_store:clean(function()
          size_count = size_count + 1
        end)
        eq(size, size_count)
      end
    )
  end)
end)
