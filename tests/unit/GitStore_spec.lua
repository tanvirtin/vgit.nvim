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
end)
